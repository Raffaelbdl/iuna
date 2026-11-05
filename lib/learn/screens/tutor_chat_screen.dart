import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/iuna_icon_button.dart';
import '../../widgets/iuna_page.dart';
import '../../widgets/snack.dart';
import '../../widgets/time_words.dart';
import '../agent/chat_controller.dart';
import '../agent/chat_store.dart';
import '../agent/tutor_prompt.dart';
import '../agent/tutor_tools.dart';
import '../db/learn_database.dart';
import '../db/learn_repository.dart';
import '../deck.dart';
import '../learn.dart';
import '../widgets/chat_view.dart';
import '../widgets/tutor_markdown.dart';
import 'learn_widgets.dart';
import '../words/tutor_words.dart';

/// A course's room ([chapterKey] null) or one chapter's lesson, which
/// also gets a Theory tab with the document the tutor writes as it goes.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({
    super.key,
    required this.env,
    required this.courseId,
    this.chapterKey,
  });

  final LearnEnv env;
  final int courseId;
  final String? chapterKey;

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen>
    with SingleTickerProviderStateMixin {
  LearnRepository get _repo => widget.env.repo;
  late final String _sessionKey = widget.chapterKey == null
      ? kRoomSessionKey
      : chapterSessionKey(widget.chapterKey!);

  CourseRow? _course;
  ChapterRow? _chapter;
  ChatController? _chat;
  TabController? _tabs;
  StreamSubscription<int>? _changes;

  @override
  void initState() {
    super.initState();
    _init();
    _changes = _repo.changes
        .where((id) => id == widget.courseId)
        .listen((_) => _reload());
  }

  @override
  void dispose() {
    _changes?.cancel();
    _chat?.dispose();
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final course = await _repo.course(widget.courseId);
    final key = widget.chapterKey;
    final chapter = key == null ? null : await _repo.chapter(widget.courseId, key);
    if (course == null || (key != null && chapter == null)) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final session = await _repo.openSession(widget.courseId, _sessionKey);
    final env = widget.env;
    final chat = env.chat(
      store: SessionChatStore(_repo, session.id),
      systemPrompt: () async => tutorSystemPrompt(
        repo: _repo,
        assets: await TutorAssets.load(),
        courseId: widget.courseId,
        sessionId: session.id,
        sessionKey: _sessionKey,
        wordLookup: await TutorWords.instance.available(),
      ),
      tools: tutorTools(
        TutorScope(repo: _repo, courseId: widget.courseId, sessionKey: _sessionKey),
        bookmarks: env.bookmarks,
      ),
      courseId: widget.courseId,
      kickoff: () async {
        if (chapter == null) return roomKickoffNote(course);
        // Opening a passed chapter is usually to reread it: don't spend a
        // model call until the learner asks something.
        if (chapter.status == ChapterStatus.passed) return null;
        return lessonKickoffNote(chapter);
      },
    );
    if (!mounted) {
      chat.dispose();
      return;
    }
    setState(() {
      _course = course;
      _chapter = chapter;
      _chat = chat;
      if (chapter != null) {
        _tabs = TabController(
          length: 2,
          vsync: this,
          initialIndex: chapter.status == ChapterStatus.passed ? 1 : 0,
        );
      }
    });
    await chat.open();
  }

  Future<void> _reload() async {
    final course = await _repo.course(widget.courseId);
    final key = widget.chapterKey;
    final chapter = key == null ? null : await _repo.chapter(widget.courseId, key);
    if (!mounted) return;
    setState(() {
      _course = course ?? _course;
      _chapter = chapter ?? _chapter;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final chapter = _chapter;
    final wrapUp = chat == null
        ? null
        : ListenableBuilder(
            listenable: chat,
            builder: (context, _) {
              final started = chat.messages.any((m) => m.role == MessageRole.user);
              final notYet = !started
                  ? 'Say something to Kuma-sensei first, then wrap up.'
                  : chat.pendingQuiz != null
                  ? 'Answer the quick check first, then wrap up.'
                  : chat.busy
                  ? 'Wait for Kuma-sensei to finish, then wrap up.'
                  : null;
              // Always tappable: a tap that can't wrap up yet says why,
              // where a greyed-out button would only say "no".
              return IunaIconButton(
                icon: Icons.flag_outlined,
                tooltip: 'Wrap up the session',
                onTap: () => notYet == null ? _wrapUp(chat) : showSnack(context, notYet),
              );
            },
          );
    final body = chat == null
        ? const Center(child: CircularProgressIndicator())
        : chapter == null
            ? ChatView(
                controller: chat,
                hint: 'Message Kuma-sensei…',
                noteCaptions: _noteCaptions,
                picker: widget.env.photos,
                bookmarks: widget.env.bookmarks,
                onOpenSettings: widget.env.openSettings,
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  ChatView(
                    controller: chat,
                    hint: 'Answer, ask, or say “next”…',
                    noteCaptions: _noteCaptions,
                    picker: widget.env.photos,
                    bookmarks: widget.env.bookmarks,
                    onOpenSettings: widget.env.openSettings,
                    onActivityTap: (tool) {
                      if (tool is CourseWriteTool) _tabs?.animateTo(1);
                    },
                    // A passed chapter's lesson opens silent (no kickoff).
                    empty: chapter.status == ChapterStatus.passed
                        ? const _Hint(
                            'This chapter is passed. Ask Kuma-sensei anything about it, or '
                            'say “quiz me” for a revision check.',
                          )
                        : null,
                  ),
                  _TheoryView(chapter: chapter, bookmarks: widget.env.bookmarks),
                ],
              );
    return IunaPage(
      title: chapter?.title ?? 'Course room',
      subtitle: _course?.title,
      trailing: wrapUp,
      below: _tabs == null
          ? null
          : TabBar(
              controller: _tabs,
              tabs: const [Tab(text: 'Lesson'), Tab(text: 'Theory')],
            ),
      body: body,
    );
  }

  Future<void> _wrapUp(ChatController chat) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Wrap up the session?',
      body:
          'Kuma-sensei saves where you are and sums up what you covered. '
          'You can keep chatting afterwards.',
      confirmLabel: 'Wrap up',
    );
    if (confirmed && mounted) await chat.sendNote(kWrapUpNote, kind: kWrapUpKind);
  }
}

const _noteCaptions = {kWrapUpKind: 'You wrapped up the session'};

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: IunaText.bodySmall.copyWith(height: 1.45, color: IunaPalette.ink3),
        ),
      ),
    );
  }
}

class _TheoryView extends StatelessWidget {
  const _TheoryView({required this.chapter, this.bookmarks});
  final ChapterRow chapter;
  final WordBookmarks? bookmarks;

  @override
  Widget build(BuildContext context) {
    final passed = chapter.status == ChapterStatus.passed;
    if (chapter.doc.trim().isEmpty) {
      return const _Hint(
        'Kuma-sensei writes the theory here as the lesson goes. It is yours '
        'to revise from, and it freezes once you pass the chapter.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (passed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, size: 14, color: IunaPalette.ink3),
                const SizedBox(width: 6),
                Text(
                  chapter.passedAt == null
                      ? 'Passed — the lesson text is locked'
                      : 'Passed on ${dayWords(chapter.passedAt!.toLocal())} — the lesson text is locked',
                  style: IunaText.caption.copyWith(color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
        LearnPanel(child: TutorMarkdown(
          chapter.doc,
          fontSize: IunaText.bodyLarge.fontSize!,
          bookmarks: bookmarks,
        )),
      ],
    );
  }
}
