import 'package:flutter/material.dart';

import '../../widgets/iuna_icon_button.dart';
import '../../widgets/iuna_page.dart';
import '../../widgets/notice.dart';
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

/// The last Ask chat, kept in memory for the app session (one per
/// `learn.sqlite`), so leaving it loses nothing until the next question
/// replaces it.
class LastAskChat {
  LastAskChat._(this.store, this.card);

  final MemoryChatStore store;

  /// The card it was asked from, for the prompt when it is reopened.
  final FocusCard? card;

  static final _slots = Expando<LastAskChat>('last Ask chat');

  static LastAskChat? of(LearnEnv env) => _slots[env.repo];

  static LastAskChat _start(LearnEnv env, FocusCard? card) =>
      _slots[env.repo] = LastAskChat._(MemoryChatStore(), card);

  /// The learner's opening message, for the way back to it; null while
  /// there is none.
  String? get preview {
    for (final m in store.messages) {
      if (m.role != MessageRole.user) continue;
      if (m.content.isNotEmpty) return m.content;
      if (m.photos.isNotEmpty) return 'A photo';
    }
    return null;
  }
}

/// A question from the Learn hub's chat bar, or from a card's: a fresh
/// chat that becomes the [LastAskChat]. [AskScreen.resume] reopens that.
class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    required this.env,
    this.question,
    this.photo,
    this.voice,
    this.card,
  })  : resume = false,
        assert(
          voice == null
              ? (question != null || photo != null)
              : (question == null && photo == null),
          'ask in text, with a photo, or by voice',
        );

  const AskScreen.resume({super.key, required this.env})
      : resume = true,
        question = null,
        photo = null,
        voice = null,
        card = null;

  final LearnEnv env;

  /// Reopen the [LastAskChat] instead of asking something new.
  final bool resume;

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
  late LastAskChat _slot = widget.resume
      ? LastAskChat.of(widget.env) ?? LastAskChat._start(widget.env, null)
      : LastAskChat._start(widget.env, widget.card);
  late ChatController _chat = _controllerFor(_slot);

  ChatController _controllerFor(LastAskChat slot) {
    final env = widget.env;
    return env.chat(
      store: slot.store,
      systemPrompt: () async => buildAskPrompt(
        await TutorAssets.load(),
        courses: await env.repo.courseSummaries(),
        preferences: await env.repo.preferences(),
        today: DateTime.now(),
        wordLookup: await TutorWords.instance.available(),
        card: slot.card,
      ),
      tools: [
        if (env.bookmarks case final bookmarks?) BookmarkWordsTool(bookmarks),
      ],
      usageKind: 'ask',
    );
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _chat.open();
    if (!mounted || widget.resume) return;
    if (widget.voice case final voice?) {
      await _chat.dictate(voice);
    } else {
      await _chat.send(widget.question ?? '', photo: widget.photo);
    }
  }

  /// Drops this chat for an empty one, about the same card if any.
  void _newChat() {
    final old = _chat;
    setState(() {
      _slot = LastAskChat._start(widget.env, _slot.card);
      _chat = _controllerFor(_slot);
    });
    _chat.open();
    // After the frame that stops listening to it.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _chat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final empty = _chat.loaded && _chat.messages.isEmpty && _chat.pendingVoice == null;
        return IunaPage(
          title: 'Ask Kuma-sensei',
          trailing: empty
              ? null
              : IunaIconButton(
                  icon: Icons.add_comment_outlined,
                  tooltip: 'New chat',
                  onTap: _chat.busy ? null : _newChat,
                ),
          body: ChatView(
            key: ObjectKey(_chat),
            controller: _chat,
            hint: empty ? 'Ask Kuma-sensei about Japanese…' : 'Ask a follow-up…',
            empty: const IunaNotice(
              text: 'A fresh chat. Kuma-sensei answers questions about Japanese.',
            ),
            picker: widget.env.photos,
            bookmarks: widget.env.bookmarks,
            onOpenSettings: widget.env.openSettings,
          ),
        );
      },
    );
  }
}
