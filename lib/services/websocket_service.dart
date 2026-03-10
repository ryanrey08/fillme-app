import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants/app_constants.dart';

/// Connection state for the WebSocket
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Represents a channel subscription
class ChannelSubscription {
  final String channelName;
  final StreamController<Map<String, dynamic>> _controller;
  
  ChannelSubscription(this.channelName)
      : _controller = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get stream => _controller.stream;
  
  void add(Map<String, dynamic> event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
  
  void close() {
    _controller.close();
  }
}

/// WebSocket service for Laravel Reverb (Pusher protocol compatible)
/// 
/// This service handles:
/// - WebSocket connection to Laravel Reverb
/// - Automatic reconnection with exponential backoff
/// - Channel subscription/unsubscription (public and private)
/// - Authentication for private channels
class WebSocketService {
  WebSocketChannel? _channel;
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  String? _socketId;
  String? _authToken;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  
  // Channel subscriptions
  final Map<String, ChannelSubscription> _subscriptions = {};
  
  // Connection state stream
  final _connectionStateController = StreamController<WebSocketConnectionState>.broadcast();
  Stream<WebSocketConnectionState> get connectionStateStream => _connectionStateController.stream;
  WebSocketConnectionState get connectionState => _connectionState;
  
  // Singleton pattern
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();
  
  /// Set the authentication token for private channels
  void setAuthToken(String? token) {
    _authToken = token;
  }
  
  /// Get the socket ID (available after connection)
  String? get socketId => _socketId;
  
  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_connectionState == WebSocketConnectionState.connected ||
        _connectionState == WebSocketConnectionState.connecting) {
      debugPrint('[WebSocket] Already connected or connecting, skipping');
      return;
    }
    
    _updateConnectionState(WebSocketConnectionState.connecting);
    
    try {
      final uri = Uri.parse(AppConstants.wsUrl);
      debugPrint('[WebSocket] Connecting to ${AppConstants.wsUrl}');
      
      // Use a timeout for the initial connection
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for the channel to be ready with a timeout
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[WebSocket] Connection timeout after 10 seconds');
          throw TimeoutException('WebSocket connection timeout');
        },
      );
      
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );
      
      debugPrint('[WebSocket] Connection initiated successfully');
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
      _channel = null;
      _handleError(e);
    }
  }
  
  /// Disconnect from the WebSocket server
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    
    // Unsubscribe from all channels
    for (final subscription in _subscriptions.values) {
      subscription.close();
    }
    _subscriptions.clear();
    
    _channel?.sink.close();
    _channel = null;
    _socketId = null;
    
    _updateConnectionState(WebSocketConnectionState.disconnected);
    debugPrint('[WebSocket] Disconnected');
  }
  
  /// Subscribe to a public channel
  Stream<Map<String, dynamic>> subscribeToChannel(String channelName) {
    if (_subscriptions.containsKey(channelName)) {
      return _subscriptions[channelName]!.stream;
    }
    
    final subscription = ChannelSubscription(channelName);
    _subscriptions[channelName] = subscription;
    
    if (_connectionState == WebSocketConnectionState.connected) {
      _sendSubscribe(channelName);
    }
    
    return subscription.stream;
  }
  
  /// Subscribe to a private channel (requires authentication)
  Stream<Map<String, dynamic>> subscribeToPrivateChannel(String channelName) {
    final fullChannelName = channelName.startsWith('private-') 
        ? channelName 
        : 'private-$channelName';
    
    if (_subscriptions.containsKey(fullChannelName)) {
      return _subscriptions[fullChannelName]!.stream;
    }
    
    final subscription = ChannelSubscription(fullChannelName);
    _subscriptions[fullChannelName] = subscription;
    
    if (_connectionState == WebSocketConnectionState.connected) {
      _sendPrivateSubscribe(fullChannelName);
    }
    
    return subscription.stream;
  }
  
  /// Unsubscribe from a channel
  void unsubscribeFromChannel(String channelName) {
    final subscription = _subscriptions.remove(channelName);
    if (subscription != null) {
      subscription.close();
      
      if (_connectionState == WebSocketConnectionState.connected) {
        _sendUnsubscribe(channelName);
      }
    }
  }
  
  /// Send a message to a channel (client events)
  void sendToChannel(String channelName, String eventName, Map<String, dynamic> data) {
    if (_connectionState != WebSocketConnectionState.connected) {
      debugPrint('[WebSocket] Cannot send message: not connected');
      return;
    }
    
    final message = {
      'event': 'client-$eventName',
      'channel': channelName,
      'data': data,
    };
    
    _sendMessage(message);
  }
  
  // Private methods
  
  void _updateConnectionState(WebSocketConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final event = data['event'] as String?;
      
      debugPrint('[WebSocket] Received event: $event');
      
      switch (event) {
        case 'pusher:connection_established':
          _handleConnectionEstablished(data);
          break;
        case 'pusher:subscription_succeeded':
          _handleSubscriptionSucceeded(data);
          break;
        case 'pusher:subscription_error':
          _handleSubscriptionError(data);
          break;
        case 'pusher:error':
          _handlePusherError(data);
          break;
        case 'pusher:pong':
          // Pong received, connection is healthy
          break;
        default:
          // Route event to appropriate channel subscription
          _routeEventToSubscription(data);
          break;
      }
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e');
    }
  }
  
  void _handleConnectionEstablished(Map<String, dynamic> data) {
    final eventData = jsonDecode(data['data'] as String) as Map<String, dynamic>;
    _socketId = eventData['socket_id'] as String?;
    
    _updateConnectionState(WebSocketConnectionState.connected);
    _reconnectAttempts = 0;
    
    debugPrint('[WebSocket] ========================================');
    debugPrint('[WebSocket] Connected with socket_id: $_socketId');
    debugPrint('[WebSocket] Auth token available: ${_authToken != null}');
    debugPrint('[WebSocket] ========================================');
    
    // Start ping timer to keep connection alive
    _startPingTimer();
    
    // Re-subscribe to all channels
    _resubscribeToChannels();
  }
  
  void _handleSubscriptionSucceeded(Map<String, dynamic> data) {
    final channel = data['channel'] as String?;
    debugPrint('[WebSocket] ✓ Successfully subscribed to channel: $channel');
  }
  
  void _handleSubscriptionError(Map<String, dynamic> data) {
    final channel = data['channel'] as String?;
    final errorData = data['data'];
    debugPrint('[WebSocket] ✗ Subscription FAILED for channel: $channel');
    debugPrint('[WebSocket] ✗ Error details: $errorData');
  }
  
  void _handlePusherError(Map<String, dynamic> data) {
    final eventData = data['data'];
    debugPrint('[WebSocket] Pusher error: $eventData');
  }
  
  void _routeEventToSubscription(Map<String, dynamic> data) {
    final channelName = data['channel'] as String?;
    final eventName = data['event'] as String?;
    debugPrint('[WebSocket] Routing event "$eventName" to channel "$channelName"');
    
    if (channelName == null) {
      debugPrint('[WebSocket] No channel name in event, skipping');
      return;
    }
    
    final subscription = _subscriptions[channelName];
    if (subscription != null) {
      debugPrint('[WebSocket] Found subscription for channel: $channelName');
      // Parse the data field if it's a string
      var eventData = data['data'];
      if (eventData is String) {
        try {
          eventData = jsonDecode(eventData);
        } catch (_) {
          // Keep as string if not valid JSON
        }
      }
      
      subscription.add({
        'event': data['event'],
        'data': eventData,
      });
      debugPrint('[WebSocket] Event added to subscription stream');
    } else {
      debugPrint('[WebSocket] No subscription found for channel: $channelName');
      debugPrint('[WebSocket] Active subscriptions: ${_subscriptions.keys.toList()}');
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('[WebSocket] Error: $error');
    _updateConnectionState(WebSocketConnectionState.error);
    _scheduleReconnect();
  }
  
  void _handleDone() {
    debugPrint('[WebSocket] Connection closed');
    _pingTimer?.cancel();
    
    if (_connectionState != WebSocketConnectionState.disconnected) {
      _updateConnectionState(WebSocketConnectionState.disconnected);
      _scheduleReconnect();
    }
  }
  
  void _scheduleReconnect() {
    if (_reconnectAttempts >= AppConstants.wsMaxReconnectAttempts) {
      debugPrint('[WebSocket] Max reconnect attempts reached');
      _updateConnectionState(WebSocketConnectionState.error);
      return;
    }
    
    _reconnectTimer?.cancel();
    
    // Exponential backoff
    final delay = AppConstants.wsReconnectDelayMs * (1 << _reconnectAttempts);
    _reconnectAttempts++;
    
    debugPrint('[WebSocket] Scheduling reconnect in ${delay}ms (attempt $_reconnectAttempts)');
    _updateConnectionState(WebSocketConnectionState.reconnecting);
    
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      connect();
    });
  }
  
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendPing();
    });
  }
  
  void _sendPing() {
    _sendMessage({'event': 'pusher:ping'});
  }
  
  void _sendSubscribe(String channelName) {
    _sendMessage({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName},
    });
  }
  
  void _sendPrivateSubscribe(String channelName) async {
    if (_authToken == null) {
      debugPrint('[WebSocket] Cannot subscribe to private channel without auth token');
      return;
    }
    
    if (_socketId == null) {
      debugPrint('[WebSocket] Cannot subscribe to private channel without socket ID');
      return;
    }
    
    try {
      // Call backend to get signed auth for private channel
      final authSignature = await _getChannelAuth(channelName);
      
      if (authSignature == null) {
        debugPrint('[WebSocket] Failed to get auth for channel: $channelName');
        return;
      }
      
      _sendMessage({
        'event': 'pusher:subscribe',
        'data': {
          'channel': channelName,
          'auth': authSignature,
        },
      });
      
      debugPrint('[WebSocket] Subscribed to private channel: $channelName');
    } catch (e) {
      debugPrint('[WebSocket] Error subscribing to private channel: $e');
    }
  }
  
  /// Get authentication signature from backend for private channel
  Future<String?> _getChannelAuth(String channelName) async {
    debugPrint('[WebSocket] Getting auth for channel: $channelName');
    debugPrint('[WebSocket] Socket ID: $_socketId');
    
    // Use the API endpoint with proper Sanctum authentication
    final authUrl = '${AppConstants.apiBaseUrl}/api/mobile/v1/broadcasting/auth';
    debugPrint('[WebSocket] Auth URL: $authUrl');
    
    try {
      final response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'socket_id': _socketId,
          'channel_name': channelName,
        }),
      );
      
      debugPrint('[WebSocket] Auth response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[WebSocket] Auth signature received for: $channelName');
        return data['auth'] as String?;
      } else {
        debugPrint('[WebSocket] ✗ Auth request FAILED: ${response.statusCode}');
        debugPrint('[WebSocket] ✗ Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[WebSocket] ✗ Error getting channel auth: $e');
      return null;
    }
  }
  
  void _sendUnsubscribe(String channelName) {
    _sendMessage({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
  }
  
  void _resubscribeToChannels() {
    for (final channelName in _subscriptions.keys) {
      if (channelName.startsWith('private-')) {
        _sendPrivateSubscribe(channelName);
      } else {
        _sendSubscribe(channelName);
      }
    }
  }
  
  void _sendMessage(Map<String, dynamic> message) {
    if (_channel == null) return;
    
    try {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
    } catch (e) {
      debugPrint('[WebSocket] Error sending message: $e');
    }
  }
  
  /// Dispose of resources
  void dispose() {
    disconnect();
    _connectionStateController.close();
  }
}
