import 'package:flutter/material.dart';

/// A one-line snack bar, skipped when [context] is gone (the usual
/// case after an await). It replaces any snack bar already showing.
///
/// [bottom] lifts it higher than the theme's nav clearance, for a
/// screen whose bottom chrome is taller than the nav (the ask bar).
void showSnack(
  BuildContext context,
  String text, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 4),
  double? bottom,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      action: action,
      duration: duration,
      margin: bottom == null ? null : EdgeInsets.fromLTRB(16, 0, 16, bottom),
      behavior: bottom == null ? null : SnackBarBehavior.floating,
    ),
  );
}

/// Logs [error] for the developer and shows the learner [message]
/// instead of the raw exception text.
void showErrorSnack(
  BuildContext context,
  String message,
  Object error, {
  SnackBarAction? action,
}) {
  debugPrint('$message ($error)');
  showSnack(context, message, action: action);
}
