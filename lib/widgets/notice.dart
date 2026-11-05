import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';
import 'cta_button.dart';

/// A centred note in place of a screen's content, with an optional way
/// on.
class IunaNotice extends StatelessWidget {
  const IunaNotice({super.key, required this.text, this.icon, this.action});

  final String text;
  final IconData? icon;
  final ({String label, VoidCallback onTap})? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final icon = this.icon;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: IunaPalette.inkMute),
              const SizedBox(height: 12),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: IunaText.body.copyWith(
                color: IunaPalette.ink3,
                height: 1.4,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              IunaCtaButton(
                label: action.label,
                shrinkWrap: true,
                onTap: action.onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What a screen shows when its data didn't load: a plain line and a
/// Retry, never the raw error.
class LoadErrorNotice extends StatelessWidget {
  const LoadErrorNotice({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IunaNotice(
      icon: Icons.error_outline_rounded,
      text: "Couldn't load this screen.",
      action: (label: 'Retry', onTap: onRetry),
    );
  }
}

/// Logs why a screen's load failed, for the developer.
void logLoadError(String where, Object error, StackTrace stack) {
  debugPrint('$where failed to load: $error\n$stack');
}
