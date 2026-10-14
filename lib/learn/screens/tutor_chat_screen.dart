import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../agent/chat_controller.dart';
import '../agent/chat_store.dart';
import '../agent/tutor_prompt.dart';
import '../agent/tutor_tools.dart';
import '../db/learn_database.dart';
import '../db/learn_repository.dart';
import '../learn.dart';
import '../widgets/chat_view.dart';
import '../widgets/tutor_markdown.dart';
import 'learn_widgets.dart';

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
        ? const SizedBox.shrink()
        : ListenableBuilder(
            listenable: chat,
            builder: (context, _) {
              final started = chat.messages.any((m) => m.role == MessageRole.user);
              return TextButton(
                onPressed: chat.busy || !started
                    ? null
                    : () => chat.sendNote(kWrapUpNote, kind: kWrapUpKind),
                child: const Text('Wrap up'),
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
              )
            : TabBarView(
                controller: _tabs,
                children: [
                  ChatView(
                    controller: chat,
                    hint: 'Answer, ask, or say “next”…',
                    noteCaptions: _noteCaptions,
                    picker: widget.env.photos,
                    onActivityTap: (tool) {
                      if (tool is CourseWriteTool) _tabs?.animateTo(1);
                    },
                    // A passed chapter's lesson opens silent (no kickoff).
                    empty: chapter.status == ChapterStatus.passed
                        ? const _PassedLessonHint()
                        : null,
                  ),
                  _TheoryView(chapter: chapter),
                ],
              );
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(chapter?.title ?? 'Course room', overflow: TextOverflow.ellipsis),
            if (_course != null)
              Text(
                _course!.title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: IunaPalette.ink3, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        actions: [wrapUp],
        bottom: _tabs == null
            ? null
            : TabBar(
                controller: _tabs,
                labelColor: IunaPalette.ink,
                unselectedLabelColor: IunaPalette.ink3,
                indicatorColor: IunaPalette.bellGold,
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Lesson'), Tab(text: 'Theory')],
              ),
      ),
      body: DecoratedBox(decoration: iunaPageBackground(), child: body),
    );
  }
}

const _noteCaptions = {kWrapUpKind: 'You wrapped up the session'};

class _PassedLessonHint extends StatelessWidget {
  const _PassedLessonHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'This chapter is passed. Ask Kuma-sensei anything about it, or '
          'say “quiz me” for a revision check.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, height: 1.45, color: IunaPalette.ink3),
        ),
      ),
    );
  }
}

class _TheoryView extends StatelessWidget {
  const _TheoryView({required this.chapter});
  final ChapterRow chapter;

  @override
  Widget build(BuildContext context) {
    final passed = chapter.status == ChapterStatus.passed;
    if (chapter.doc.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Kuma-sensei writes the theory here as the lesson goes. It is yours '
            'to revise from, and it freezes once you pass the chapter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.45, color: IunaPalette.ink3),
          ),
        ),
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
                      ? 'Passed — this text is frozen'
                      : 'Passed on ${isoDay(chapter.passedAt!.toLocal())} — this text is frozen',
                  style: const TextStyle(fontSize: 12, color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
        LearnPanel(child: TutorMarkdown(chapter.doc, fontSize: 15)),
      ],
    );
  }
}
