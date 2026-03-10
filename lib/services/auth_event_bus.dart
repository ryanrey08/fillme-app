import 'dart:async';

/// Events that can be emitted for authentication state changes
enum AuthEvent {
  /// Token has expired or user is unauthenticated (401 response)
  tokenExpired,

  /// User's session was invalidated server-side
  sessionInvalidated,

  /// Force logout triggered by admin or security measure
  forceLogout,
}

/// Singleton event bus for authentication events
/// This allows the ApiService to notify the app about auth state changes
/// without creating circular dependencies
class AuthEventBus {
  AuthEventBus._();

  static final AuthEventBus _instance = AuthEventBus._();
  static AuthEventBus get instance => _instance;

  final _controller = StreamController<AuthEvent>.broadcast();

  /// Stream of auth events that can be listened to
  Stream<AuthEvent> get stream => _controller.stream;

  /// Emit a token expired event (called when 401 is received)
  void emitTokenExpired() {
    if (!_controller.isClosed) {
      _controller.add(AuthEvent.tokenExpired);
    }
  }

  /// Emit a session invalidated event
  void emitSessionInvalidated() {
    if (!_controller.isClosed) {
      _controller.add(AuthEvent.sessionInvalidated);
    }
  }

  /// Emit a force logout event
  void emitForceLogout() {
    if (!_controller.isClosed) {
      _controller.add(AuthEvent.forceLogout);
    }
  }

  /// Dispose the stream controller (typically not needed as this is a singleton)
  void dispose() {
    _controller.close();
  }
}
