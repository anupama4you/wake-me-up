import 'package:flutter/material.dart';

/// Centralized error handling utility for showing user-friendly error messages
class ErrorHandler {
  /// Show an error dialog to the user
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onAction();
              },
              child: Text(actionLabel),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show an error snackbar (less intrusive than dialog)
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a success snackbar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a warning snackbar
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber.shade400,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handle location permission errors with actionable messages
  static Future<void> handleLocationPermissionError(
    BuildContext context,
    String permissionStatus,
  ) async {
    String title = 'Location Permission Required';
    String message;
    String? actionLabel;
    VoidCallback? onAction;

    switch (permissionStatus.toLowerCase()) {
      case 'denied':
        message =
            'Location permission is required to create location-based alarms. '
            'Please grant location permission in the next dialog.';
        break;
      case 'deniedforever':
      case 'permanentlydenied':
        title = 'Location Permission Denied';
        message =
            'Location permission has been permanently denied. '
            'Please enable it in your device Settings:\n\n'
            'Settings → WakeMeUp → Location → Always';
        actionLabel = 'Open Settings';
        onAction = () {
          // Will be handled by the calling code with openAppSettings()
        };
        break;
      case 'restricted':
        message =
            'Location services are restricted on this device. '
            'This may be due to parental controls or device management policies.';
        break;
      default:
        message =
            'Unable to access location services. Please check your device settings.';
    }

    await showErrorDialog(
      context,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Handle geofencing errors
  static Future<void> handleGeofenceError(
    BuildContext context,
    String error,
  ) async {
    String title = 'Geofencing Error';
    String message;

    if (error.toLowerCase().contains('permission')) {
      message =
          'Background location permission is required for geofencing. '
          'Please enable "Always Allow" location access in Settings.';
    } else if (error.toLowerCase().contains('service')) {
      message =
          'Unable to start the geofencing service. '
          'Please ensure location services are enabled and try again.';
    } else {
      message =
          'An error occurred while setting up your alarm: $error\n\n'
          'Please try again or contact support if the problem persists.';
    }

    await showErrorDialog(
      context,
      title: title,
      message: message,
    );
  }

  /// Handle network/API errors
  static void handleNetworkError(
    BuildContext context,
    dynamic error,
  ) {
    String message;

    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      message =
          'No internet connection. Please check your network and try again.';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Request timed out. Please check your connection and try again.';
    } else if (error.toString().contains('API_KEY')) {
      message =
          'Invalid API configuration. Please contact support.';
    } else {
      message = 'Network error occurred. Please try again later.';
    }

    showErrorSnackBar(context, message);
  }

  /// Handle storage/database errors
  static Future<void> handleStorageError(
    BuildContext context,
    String operation,
    dynamic error,
  ) async {
    await showErrorDialog(
      context,
      title: 'Storage Error',
      message:
          'Failed to $operation. Your data may not have been saved.\n\n'
          'Error: $error\n\n'
          'Please try again or restart the app.',
    );
  }

  /// Generic error handler with logging
  static Future<T?> handleError<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    required String operationName,
    bool showDialog = true,
    bool showSnackBar = false,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      debugPrint('❌ Error in $operationName: $e');
      debugPrint('Stack trace: $stackTrace');

      if (context.mounted) {
        final message = 'Failed to $operationName. Please try again.';
        if (showDialog) {
          await showErrorDialog(
            context,
            title: 'Error',
            message: '$message\n\nError: $e',
          );
        } else if (showSnackBar) {
          showErrorSnackBar(context, message);
        }
      }
      return null;
    }
  }
}
