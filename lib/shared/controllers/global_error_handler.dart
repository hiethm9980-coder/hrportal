import 'package:flutter/material.dart';
import 'package:hr_portal/core/localization/app_localizations.dart';

import '../../core/errors/exceptions.dart';

/// Describes what the UI should do in response to an error.
enum ErrorAction {
  /// Show inline field errors (ValidationException).
  showFieldErrors,

  /// Show a non-blocking snackbar message.
  showSnackbar,

  /// Show a blocking dialog requiring dismissal.
  showDialog,

  /// Navigate to login (session expired).
  redirectToLogin,

  /// Show a full-screen offline/error state.
  showFullScreen,
}

/// Processed error ready for UI consumption.
class UiError {
  final ErrorAction action;
  final String title;
  final String message;
  final Map<String, List<String>> fieldErrors;
  final String? traceId;

  const UiError({
    required this.action,
    required this.title,
    required this.message,
    this.fieldErrors = const {},
    this.traceId,
  });
}

/// Maps [ApiException] subtypes to [UiError] for presentation.
///
/// Usage in any provider/controller:
/// ```dart
/// } on ApiException catch (e) {
///   state = AsyncError(GlobalErrorHandler.handle(e), StackTrace.current);
/// }
/// ```
///
/// Usage in UI:
/// ```dart
/// ref.listen(someProvider, (_, next) {
///   if (next is AsyncError) {
///     final uiError = next.error as UiError;
///     GlobalErrorHandler.show(context, uiError, ref);
///   }
/// });
/// ```
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Convert an [ApiException] into a UI-ready [UiError].
  static UiError handle(Object error) {
    if (error is ValidationException) {
      return UiError(
        action: ErrorAction.showFieldErrors,
        title: 'Invalid data',
        message: error.message,
        fieldErrors: error.fieldErrors,
        traceId: error.traceId,
      );
    }

    if (error is TokenExpiredException || error is TokenInvalidException) {
      return UiError(
        action: ErrorAction.redirectToLogin,
        title: 'Session expired',
        message: 'Your session has expired. Please sign in again.',
        traceId: (error as ApiException).traceId,
      );
    }

    if (error is AuthRequiredException) {
      return UiError(
        action: ErrorAction.redirectToLogin,
        title: 'Not authenticated',
        message: 'Please sign in.',
        traceId: error.traceId,
      );
    }

    if (error is AccessDeniedException ||
        error is InsufficientPermissionsException) {
      return UiError(
        action: ErrorAction.showDialog,
        title: 'Unauthorized',
        message: (error as ApiException).message,
        traceId: (error).traceId,
      );
    }

    if (error is ResourceConflictException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Conflict',
        message: error.message,
        traceId: error.traceId,
      );
    }

    if (error is BusinessRuleException) {
      return UiError(
        action: ErrorAction.showDialog,
        title: 'Not allowed',
        message: error.message,
        traceId: error.traceId,
      );
    }

    if (error is ResourceNotFoundException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Not found',
        message: error.message,
        traceId: error.traceId,
      );
    }

    if (error is RateLimitedException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Too many requests',
        message: 'Please wait a moment and try again.',
        traceId: error.traceId,
      );
    }

    if (error is NetworkException) {
      return UiError(
        action: ErrorAction.showFullScreen,
        title: 'No connection',
        message: 'Check your internet connection and try again.',
      );
    }

    if (error is TimeoutException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Timeout',
        message: 'The server is slow. Try again.',
      );
    }

    if (error is ServerException || error is ServiceUnavailableException) {
      return UiError(
        action: ErrorAction.showFullScreen,
        title: 'Server error',
        message: 'A technical error occurred. Try again later.',
        traceId: (error as ApiException).traceId,
      );
    }

    // Unknown error fallback
    if (error is ApiException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Error',
        message: error.message,
        traceId: error.traceId,
      );
    }

    return UiError(
      action: ErrorAction.showSnackbar,
      title: 'Unexpected error',
      message: error.toString(),
    );
  }

  /// Present the [UiError] to the user via the appropriate mechanism.
  static void show(BuildContext context, UiError error) {
    switch (error.action) {
      case ErrorAction.showFieldErrors:
        // Field errors are handled inline by form widgets.
        // Show a summary snackbar as well.
        _showSnackbar(context, error.message, isError: true);
        break;

      case ErrorAction.showSnackbar:
        _showSnackbar(context, error.message, isError: true);
        break;

      case ErrorAction.showDialog:
        _showErrorDialog(context, error.title, error.message);
        break;

      case ErrorAction.redirectToLogin:
        // Handled by SessionManager → GoRouter redirect.
        // Show a brief message.
        _showSnackbar(context, error.message, isError: true);
        break;

      case ErrorAction.showFullScreen:
        // The screen itself should check for this state and show
        // the ErrorFullScreen widget. Snackbar as fallback.
        _showSnackbar(context, error.message, isError: true);
        break;
    }
  }

  static void _showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.tr(context)),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title.tr(context)),
        content: Text(message.tr(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('OK'.tr(context)),
          ),
        ],
      ),
    );
  }
}
