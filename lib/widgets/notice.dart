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

/// A screen whose data comes from one async [load]: a spinner, then the
/// content, or [LoadErrorNotice] if the fetch threw.
mixin LoadGate<T extends StatefulWidget> on State<T> {
  bool loading = true;
  bool failed = false;

  /// Fetches through [guardLoad] and shows the result with [showLoaded].
  Future<void> load();

  /// [fetch]'s result, or null once it has thrown: logged under [where]
  /// and the retry notice shown. With [keepShown], a throw while content
  /// is on screen leaves that content up.
  Future<R?> guardLoad<R extends Object>(
    String where,
    Future<R> Function() fetch, {
    bool keepShown = false,
  }) async {
    try {
      return await fetch();
    } catch (e, s) {
      logLoadError(where, e, s);
      if (mounted && !(keepShown && !loading && !failed)) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
      return null;
    }
  }

  /// Applies [update] and leaves the spinner or the retry notice.
  void showLoaded([VoidCallback? update]) => setState(() {
    update?.call();
    loading = false;
    failed = false;
  });

  void retry() {
    setState(() {
      loading = true;
      failed = false;
    });
    load();
  }

  /// The spinner, the retry notice, or [content].
  Widget gated(Widget Function() content) => loading
      ? const Center(child: CircularProgressIndicator())
      : failed
      ? LoadErrorNotice(onRetry: retry)
      : content();
}
