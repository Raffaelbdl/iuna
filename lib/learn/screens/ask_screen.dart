import 'package:flutter/material.dart';

import '../../widgets/confirm_dialog.dart';
import '../../widgets/iuna_page.dart';
import '../agent/bookmark_tool.dart';
import '../agent/chat_controller.dart';
import '../agent/chat_store.dart';
import '../agent/tutor_prompt.dart';
import '../db/learn_database.dart' show MessageRole;
import '../deck.dart';
import '../learn.dart';
import '../photo/photo.dart';
import '../voice/dictation.dart';
import '../widgets/chat_view.dart';
import '../words/tutor_words.dart';

/// A question from the Learn hub's chat bar, or from a card's. Kept in
/// memory only, so every question starts a fresh chat.
class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    required this.env,
    this.question,
    this.photo,
    this.voice,
    this.card,
  }) : assert(
          voice == null
              ? (question != null || photo != null)
              : (question == null && photo == null),
          'ask in text, with a photo, or by voice',
        );

  final LearnEnv env;

  /// The learner's opening message, sent as soon as the chat is up…
  final String? question;

  /// …with the photo they attached to it, or a photo on its own…
  final Photo? photo;

  /// …or held-to-speak on the hub, transcribed here first.
  final VoiceClip? voice;

  /// The card it was asked from, when it was.
  final FocusCard? card;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late final ChatController _chat = widget.env.chat(
    store: MemoryChatStore(),
    systemPrompt: () async => buildAskPrompt(
      await TutorAssets.load(),
      courses: await widget.env.repo.courseSummaries(),
      preferences: await widget.env.repo.preferences(),
      today: DateTime.now(),
      wordLookup: await TutorWords.instance.available(),
      card: widget.card,
    ),
    tools: [
      if (widget.env.bookmarks case final bookmarks?) BookmarkWordsTool(bookmarks),
    ],
    usageKind: 'ask',
  );

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _chat.open();
    if (!mounted) return;
    if (widget.voice case final voice?) {
      await _chat.dictate(voice);
    } else {
      await _chat.send(widget.question ?? '', photo: widget.photo);
    }
  }

  VoidCallback? get _openSettings => switch (widget.env.openSettings) {
        final open? => () => open(context),
        null => null,
      };

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  /// Nothing here is kept, so leaving a chat Kuma has answered asks
  /// first.
  bool get _worthKeeping =>
      _chat.messages.any((m) => m.role == MessageRole.assistant);

  Future<void> _confirmLeave() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Leave this chat?',
      body: "It isn't saved, so Kuma-sensei's answers go with it.",
      confirmLabel: 'Leave',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, child) => PopScope<Object?>(
        canPop: !_worthKeeping,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmLeave();
        },
        child: child!,
      ),
      child: IunaPage(
        title: 'Ask Kuma-sensei',
        body: ChatView(
          controller: _chat,
          hint: 'Ask a follow-up…',
          picker: widget.env.photos,
          bookmarks: widget.env.bookmarks,
          onOpenSettings: _openSettings,
        ),
      ),
    );
  }
}
