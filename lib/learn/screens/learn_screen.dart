import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/database.dart';
import '../../screens/app_nav.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/hex_bg.dart';
import '../../widgets/iuna_bottom_nav.dart';
import '../../widgets/kuma_mascot.dart';
import '../../widgets/section_header.dart';
import '../db/learn_repository.dart';
import '../learn.dart';
import '../photo/photo.dart';
import '../widgets/chat_composer.dart';
import 'ask_screen.dart';
import 'course_screen.dart';
import 'learn_widgets.dart';
import 'new_course_sheet.dart';

/// The Learn tab: courses, and a chat bar for quick questions (mini-games
/// will slot in as another section here).
class LearnScreen extends StatefulWidget {
  const LearnScreen({
    super.key,
    required this.db,
    this.env,
    this.kumaSeed,
  });

  final AppDatabase db;
  final LearnEnv? env;
  final int? kumaSeed;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final LearnEnv _env = widget.env ?? LearnEnv.live(widget.db);
  final _question = TextEditingController();
  Photo? _photo;
  List<CourseSummary> _courses = const [];
  bool _loading = true;
  StreamSubscription<int>? _changes;

  @override
  void initState() {
    super.initState();
    _load();
    _changes = _env.repo.changes.listen((_) => _loadIfShown());
  }

  /// Under a course the tutor writes at every step; [_openCourse]
  /// reloads once it pops instead.
  void _loadIfShown() {
    if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    _question.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final courses = await _env.repo.courseSummaries();
    if (!mounted) return;
    setState(() {
      _courses = courses;
      _loading = false;
    });
  }

  /// Each question opens its own Ask chat, so every one starts fresh.
  void _ask() {
    final question = _question.text.trim();
    final photo = _photo;
    if (question.isEmpty && photo == null) return;
    _question.clear();
    setState(() => _photo = null);
    _openAsk(AskScreen(
      env: _env,
      question: question.isEmpty ? null : question,
      photo: photo,
    ));
  }

  void _openAsk(AskScreen ask) {
    // Or the bar takes focus back on return, and the keyboard with it.
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ask));
  }

  Future<void> _openCourse(int id, {bool openRoom = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseScreen(env: _env, courseId: id, openRoomOnStart: openRoom),
    ));
    if (mounted) await _load();
  }

  Future<void> _newCourse() async {
    final course = await showNewCourseSheet(context, _env.repo);
    if (course == null || !mounted) return;
    await _openCourse(course.id, openRoom: true);
  }

  @override
  Widget build(BuildContext context) {
    // Asked above the Scaffold: its body only sees the keyboard as a
    // shorter box.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 9)),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 190),
                      children: [
                        _Header(kumaSeed: widget.kumaSeed),
                        IunaSectionHeader(
                          'Courses',
                          padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
                          trailing: TextButton.icon(
                            onPressed: _newCourse,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New course'),
                            style: TextButton.styleFrom(foregroundColor: IunaPalette.ink2),
                          ),
                        ),
                        if (_courses.isEmpty)
                          const LearnPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'One course per thing you want to master',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: IunaPalette.ink),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Kuma-sensei probes what you know, plans chapters to the '
                                  'edge of it, and keeps notes between sessions.',
                                  style: TextStyle(fontSize: 12, height: 1.4, color: IunaPalette.ink3),
                                ),
                              ],
                            ),
                          ),
                        for (final s in _courses) ...[
                          _CourseTile(summary: s, onTap: () => _openCourse(s.course.id)),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: IunaNavFade(height: 190)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: ChatComposer(
                      controller: _question,
                      hint: 'Ask Kuma-sensei anything…',
                      onSend: _ask,
                      recorder: _env.dictation?.recorder,
                      onVoice: (clip) => _openAsk(AskScreen(env: _env, voice: clip)),
                      picker: _env.photos,
                      photo: _photo,
                      onPhoto: _env.photos == null
                          ? null
                          : (photo) => setState(() => _photo = photo),
                    ),
                  ),
                  // While typing, the bar sits right on the keyboard.
                  if (!typing) AppBottomNav(db: widget.db, active: IunaNavTab.learn),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.kumaSeed});
  final int? kumaSeed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KumaMascot(size: 64, seed: kumaSeed),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learn',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: IunaPalette.ink),
              ),
              SizedBox(height: 2),
              Text(
                'Kuma-sensei teaches; you do the thinking.',
                style: TextStyle(fontSize: 13, color: IunaPalette.ink3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.summary, required this.onTap});

  final CourseSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final String line;
    if (s.chapterCount == 0) {
      line = 'Not planned yet — start in the course room';
    } else if (s.current == null) {
      line = 'All ${s.chapterCount} chapters passed 完';
    } else {
      line = 'Now: ${s.current!.title}';
    }
    return LearnPanel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.course.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: IunaPalette.ink),
                ),
              ),
              if (s.chapterCount > 0)
                Text(
                  '${s.passedCount}/${s.chapterCount}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: IunaPalette.ink2),
                ),
              const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
            ],
          ),
          const SizedBox(height: 4),
          Text(line, style: const TextStyle(fontSize: 12, color: IunaPalette.ink3)),
          if (s.chapterCount > 0) ...[
            const SizedBox(height: 10),
            LearnProgressBar(done: s.passedCount, total: s.chapterCount),
          ],
        ],
      ),
    );
  }
}
