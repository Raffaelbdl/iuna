import 'package:flutter/material.dart';

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
    this.collapsed = false,
  });

  /// How far a screen's content scrolls clear of the bar and the nav.
  static const double inset = 190;

  /// How far a snack bar sits above the screen bottom to clear the bar
  /// and the nav.
  static const double snackInset = 150;

  final LearnEnv env;
  final String hint;
  final Widget nav;

  /// The card the chat is about, read when a message is sent.
  final FocusCard Function()? card;

  /// Runs once the Ask chat is closed.
  final VoidCallback? onReturn;

  /// Tucks the composer away, leaving the nav, while the screen scrolls
  /// down to read. A half-written question keeps it out.
  final bool collapsed;

  @override
  State<AskBar> createState() => _AskBarState();
}

class _AskBarState extends State<AskBar> with WidgetsBindingObserver {
  final _question = TextEditingController();
  Photo? _photo;
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
    setState(() => _typing = typing);
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
    final env = widget.env;
    final hidden = widget.collapsed &&
        !_typing &&
        _question.text.trim().isEmpty &&
        _photo == null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: hidden
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: ChatComposer(
                    controller: _question,
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
        ),
        if (!_typing) widget.nav,
      ],
    );
  }
}
