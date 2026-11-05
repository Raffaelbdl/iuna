import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// Cancel / [confirmLabel]; true only when the learner confirms. A
/// [destructive] confirm (delete, remove, replace) is drawn in red.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive ? destructiveButtonStyle() : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A [FilledButton] for an action that throws something away.
ButtonStyle destructiveButtonStyle() => FilledButton.styleFrom(
  backgroundColor: IunaPalette.danger,
  foregroundColor: IunaPalette.paper,
  // Plain red, not the theme's honey.
  backgroundBuilder: (context, states, child) =>
      child ?? const SizedBox.shrink(),
);
