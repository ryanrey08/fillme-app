import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_event_bus.dart';
import '../../providers/auth_provider.dart';

/// A widget that listens for authentication events and handles auto-logout
/// when the token expires or the user becomes unauthenticated.
///
/// Wrap your app's main content with this widget to enable auto-logout functionality.
class AutoLogoutListener extends ConsumerStatefulWidget {
  final Widget child;

  const AutoLogoutListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<AutoLogoutListener> createState() => _AutoLogoutListenerState();
}

class _AutoLogoutListenerState extends ConsumerState<AutoLogoutListener> {
  StreamSubscription<AuthEvent>? _subscription;
  bool _isHandlingLogout = false;

  @override
  void initState() {
    super.initState();
    _subscription = AuthEventBus.instance.stream.listen(_handleAuthEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthEvent(AuthEvent event) async {
    // Prevent multiple simultaneous logout attempts
    if (_isHandlingLogout) return;

    switch (event) {
      case AuthEvent.tokenExpired:
        await _handleTokenExpired();
        break;
      case AuthEvent.sessionInvalidated:
        await _handleSessionInvalidated();
        break;
      case AuthEvent.forceLogout:
        await _handleForceLogout();
        break;
    }
  }

  Future<void> _handleTokenExpired() async {
    _isHandlingLogout = true;
    try {
      // Trigger force logout
      await ref.read(authProvider.notifier).forceLogout(
        reason: 'Your session has expired. Please login again.',
      );

      // Show a snackbar notification if the widget is still mounted
      if (mounted) {
        _showLogoutSnackBar('Session expired. Please login again.');
      }
    } finally {
      _isHandlingLogout = false;
    }
  }

  Future<void> _handleSessionInvalidated() async {
    _isHandlingLogout = true;
    try {
      await ref.read(authProvider.notifier).forceLogout(
        reason: 'Your session was invalidated. Please login again.',
      );

      if (mounted) {
        _showLogoutSnackBar('Session invalidated. Please login again.');
      }
    } finally {
      _isHandlingLogout = false;
    }
  }

  Future<void> _handleForceLogout() async {
    _isHandlingLogout = true;
    try {
      await ref.read(authProvider.notifier).forceLogout(
        reason: 'You have been logged out.',
      );

      if (mounted) {
        _showLogoutSnackBar('You have been logged out.');
      }
    } finally {
      _isHandlingLogout = false;
    }
  }

  void _showLogoutSnackBar(String message) {
    // Use maybeOf to safely get ScaffoldMessenger - it may not be available
    // if this widget is above MaterialApp in the widget tree
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('[AutoLogoutListener] ScaffoldMessenger not available, skipping snackbar: $message');
      return;
    }
    
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
