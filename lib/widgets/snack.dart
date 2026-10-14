import 'package:flutter/material.dart';

/// A one-line snack bar, skipped when [context] is gone (the usual
/// case after an await).
void showSnack(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text(text)));
}
