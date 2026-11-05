import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../deck.dart';
import '../learn.dart';
import '../photo/photo.dart';
import '../screens/ask_screen.dart';
import '../voice/dictation.dart';
import 'chat_composer.dart';

/// The chat bar a screen pins over its bottom nav: each message opens a
/// fresh Ask chat. While the keyboard is up the nav steps aside, so the
/// bar sits right on the keyboard.
class AskBar extends StatefulWidget {
  const AskBar({
    super.key,
    required this.env,
    required this.hint,
    required this.nav,
    this.card,
    this.onReturn,
    this.leading,
    this.folded,
  });

  /// How far a screen's content scrolls clear of the bar and the nav.
  static const double inset = 190;

  final LearnEnv env;
  final String hint;
  final Widget nav;

  /// The card the chat is about, read when a message is sent.
  final FocusCard Function()? card;

  /// Runs once the Ask chat is closed.
  final VoidCallback? onReturn;

  /// Shown beside the composer.
  final Widget? leading;

  /// Shown instead of the composer until it calls `open`. The bar folds
  /// back when the keyboard closes with nothing written.
  final Widget Function(VoidCallback open)? folded;

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> with WidgetsBindingObserver {
  final _question = TextEditingController();
  Photo? _photo;
  bool _open = false;
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typing = _keyboardUp();
  }

  @override
  void didUpdateWidget(AskBar old) {
    super.didUpdateWidget(old);
    if (old.folded == null && widget.folded != null) _open = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _question.dispose();
    super.dispose();
  }

  // The View, not MediaQuery: under a Scaffold that resizes for the
  // keyboard, the body's MediaQuery never sees the inset.
  bool _keyboardUp() => View.of(context).viewInsets.bottom > 0;

  @override
  void didChangeMetrics() {
    final typing = _keyboardUp();
    if (typing == _typing) return;
    setState(() {
      _typing = typing;
      // Android's back closes the keyboard before anything else.
      if (!typing && _question.text.trim().isEmpty && _photo == null) _open = false;
    });
  }

  void _send() {
    final question = _question.text.trim();
    final photo = _photo;
    if (question.isEmpty && photo == null) return;
    _question.clear();
    setState(() => _photo = null);
    _ask(question: question.isEmpty ? null : question, photo: photo);
  }

  Future<void> _ask({String? question, Photo? photo, VoiceClip? voice}) async {
    // Or the bar takes focus back on return, and the keyboard with it.
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AskScreen(
        env: widget.env,
        question: question,
        photo: photo,
        voice: voice,
        card: widget.card?.call(),
      ),
    ));
    if (mounted) widget.onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final folded = widget.folded;
    final leading = widget.leading;
    final env = widget.env;
    final bar = folded != null && !_open
        ? folded(() => setState(() => _open = true))
        : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 8)],
              Expanded(
                child: ChatComposer(
                  controller: _question,
                  // Unfolded by a tap that asked for it.
                  autofocus: folded != null,
                  hint: widget.hint,
                  onSend: _send,
                  recorder: env.dictation?.recorder,
                  onVoice: (clip) => _ask(voice: clip),
                  picker: env.photos,
                  photo: _photo,
                  onPhoto: env.photos == null
                      ? null
                      : (photo) => setState(() => _photo = photo),
                ),
              ),
            ],
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: bar),
        if (!_typing) widget.nav,
      ],
    );
  }
}

/// A frosted pill for an [AskBar]: an icon and a label, or the icon
/// alone as a round button beside the open composer.
class AskBarButton extends StatelessWidget {
  const AskBarButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final glyph = busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 20, color: IunaPalette.ink2);
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 48,
          width: label == null ? 48 : null,
          decoration: ghostPillDecoration(
            color: const Color(0xE6FFFDF6),
            boxShadow: panelShadow(),
          ),
          child: label == null
              ? Center(child: glyph)
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      glyph,
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: IunaPalette.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
