import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../agent/bookmark_tool.dart';
import '../agent/chat_controller.dart';
import '../agent/chat_store.dart';
import '../agent/tutor_prompt.dart';
import '../learn.dart';
import '../photo/photo.dart';
import '../voice/dictation.dart';
import '../widgets/chat_view.dart';

/// A question from the Learn hub's chat bar. Kept in memory only, so every
/// question starts a fresh chat.
class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    required this.env,
    this.question,
    this.photo,
    this.voice,
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

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      appBar: AppBar(title: const Text('Ask Kuma-sensei')),
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: ChatView(
          controller: _chat,
          hint: 'Ask a follow-up…',
          picker: widget.env.photos,
        ),
      ),
    );
  }
}
