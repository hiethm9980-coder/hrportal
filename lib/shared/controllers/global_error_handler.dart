import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Pre-formatted text for the "copy to clipboard" button. When the
  /// server supplied one we keep it verbatim; otherwise we fall back to
  /// [message] + optional trace id so the copy button still works.
  final String? copyText;

  const UiError({
    required this.action,
    required this.title,
    required this.message,
    this.fieldErrors = const {},
    this.traceId,
    this.copyText,
  });

  /// Best-effort copy payload — uses [copyText] when available, otherwise
  /// falls back to a locally-assembled blob.
  String get effectiveCopyText {
    if (copyText != null && copyText!.trim().isNotEmpty) return copyText!;
    final parts = <String>[message];
    if (traceId != null && traceId!.isNotEmpty) {
      parts.add('(Trace ID: $traceId)');
    }
    return parts.join('\n\n');
  }
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
///     GlobalErrorHandler.show(context, uiError);
///   }
/// });
/// ```
class GlobalErrorHandler {
  GlobalErrorHandler._();

  /// Convert an [ApiException] into a UI-ready [UiError].
  ///
  /// Design rule: **server messages win**. The backend now ships
  /// pre-localized, user-friendly Arabic strings in [ApiException.message]
  /// (e.g. `"حقل العنوان مطلوب."`). We forward them verbatim. Only fall
  /// back to i18n-keyed defaults for client-side errors (Network /
  /// Timeout) where there is no server response, OR when the server
  /// message is unhelpfully empty.
  static UiError handle(Object error) {
    // Shared helper: prefer the server's message, else the given fallback.
    String pickMessage(ApiException e, String fallback) {
      final m = e.message.trim();
      return m.isNotEmpty ? m : fallback;
    }

    if (error is ValidationException) {
      return UiError(
        action: ErrorAction.showFieldErrors,
        title: 'Invalid data',
        message: pickMessage(error, 'Invalid data'),
        fieldErrors: error.fieldErrors,
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is TokenExpiredException || error is TokenInvalidException) {
      return UiError(
        action: ErrorAction.redirectToLogin,
        title: 'Session expired',
        message: pickMessage(
            error as ApiException,
            'Your session has expired. Please sign in again.'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is AuthRequiredException) {
      return UiError(
        action: ErrorAction.redirectToLogin,
        title: 'Not authenticated',
        message: pickMessage(error, 'Please sign in.'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is AccessDeniedException ||
        error is InsufficientPermissionsException) {
      // ACCESS_DENIED now comes with a rich Arabic explanation from the
      // server ("لا يمكنك تغيير حالة المهمة — ..."); a snackbar is a
      // better fit than a modal dialog.
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Unauthorized',
        message: pickMessage(error as ApiException, 'Unauthorized'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is ResourceConflictException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Conflict',
        message: pickMessage(error, 'Conflict'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is BusinessRuleException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Not allowed',
        message: pickMessage(error, 'Not allowed'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is ResourceNotFoundException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Not found',
        message: pickMessage(error, 'Not found'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is RateLimitedException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Too many requests',
        message: pickMessage(
            error, 'Please wait a moment and try again.'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    if (error is NetworkException) {
      // Client-side error — no server message.
      return const UiError(
        action: ErrorAction.showFullScreen,
        title: 'No connection',
        message: 'Check your internet connection and try again.',
      );
    }

    if (error is TimeoutException) {
      // Client-side error — no server message.
      return const UiError(
        action: ErrorAction.showSnackbar,
        title: 'Timeout',
        message: 'The server is slow. Try again.',
      );
    }

    if (error is ServerException || error is ServiceUnavailableException) {
      return UiError(
        action: ErrorAction.showFullScreen,
        title: 'Server error',
        message: pickMessage(error as ApiException,
            'A technical error occurred. Try again later.'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    // Unknown ApiException (new error code we haven't mapped yet).
    if (error is ApiException) {
      return UiError(
        action: ErrorAction.showSnackbar,
        title: 'Error',
        message: pickMessage(error, 'Error'),
        traceId: error.traceId,
        copyText: error.copyText,
      );
    }

    // Fully unknown error (not from our API layer).
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
      case ErrorAction.showSnackbar:
      case ErrorAction.redirectToLogin:
      case ErrorAction.showFullScreen:
        // Snackbar is the fallback for all of these. `redirectToLogin` is
        // additionally handled upstream by SessionManager → router; the
        // snackbar is just a user-visible breadcrumb.
        _showSnackbar(context, error);
        break;

      case ErrorAction.showDialog:
        _showErrorDialog(context, error);
        break;
    }
  }

  // ── Private: snackbar with copy button ─────────────────────────────

  static void _showSnackbar(BuildContext context, UiError error) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final hasCopy = error.copyText != null || error.traceId != null;
    final displayMessage =
        error.message.isEmpty ? error.title.tr(context) : error.message;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        // A bit longer than the old 4s — gives the user time to read a
        // multi-field validation summary AND hit the copy icon.
        duration: const Duration(seconds: 6),
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                // Server messages come pre-translated. We still run `.tr`
                // as a no-op pass-through so purely-client fallbacks
                // (e.g. 'No connection') get localized too.
                displayMessage.tr(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasCopy) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'Copy error details'.tr(context),
                onPressed: () => _copyAndAck(context, error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Private: dialog with copy action ───────────────────────────────

  static void _showErrorDialog(BuildContext context, UiError error) {
    if (!context.mounted) return;
    final hasCopy = error.copyText != null || error.traceId != null;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          error.title.tr(dialogContext),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          error.message.tr(dialogContext),
          style: const TextStyle(fontFamily: 'Cairo', height: 1.4),
        ),
        actions: [
          if (hasCopy)
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(
                'Copy error details'.tr(dialogContext),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _copyAndAck(context, error);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'OK'.tr(dialogContext),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Private: clipboard write + acknowledgement toast ───────────────

  static Future<void> _copyAndAck(
      BuildContext context, UiError error) async {
    await Clipboard.setData(ClipboardData(text: error.effectiveCopyText));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Error details copied'.tr(context),
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
