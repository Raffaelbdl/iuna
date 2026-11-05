import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/database.dart';
import '../../screens/app_nav.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/hex_bg.dart';
import '../../widgets/iuna_bottom_nav.dart';
import '../../widgets/kuma_mascot.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tab_header.dart';
import '../db/learn_repository.dart';
import '../learn.dart';
import '../widgets/ask_bar.dart';
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
                  : Column(
                      children: [
                        const IunaTabHeader('Learn'),
                        Expanded(child: _courseList()),
                      ],
                    ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: IunaNavFade(height: AskBar.inset)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AskBar(
                env: _env,
                hint: 'Ask Kuma-sensei anything…',
                nav: AppBottomNav(db: widget.db, active: IunaNavTab.learn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, AskBar.inset),
      children: [
        _Intro(kumaSeed: widget.kumaSeed),
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
          LearnPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One course per thing you want to master',
                  style: IunaText.label.copyWith(fontWeight: FontWeight.w700, color: IunaPalette.ink),
                ),
                SizedBox(height: 4),
                Text(
                  'Kuma-sensei probes what you know, plans chapters to the '
                  'edge of it, and keeps notes between sessions.',
                  style: IunaText.caption.copyWith(height: 1.4, color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
        for (final s in _courses) ...[
          _CourseTile(summary: s, onTap: () => _openCourse(s.course.id)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Kuma-sensei and what the tab is for, under the tab header.
class _Intro extends StatelessWidget {
  const _Intro({this.kumaSeed});
  final int? kumaSeed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KumaMascot(size: 56, seed: kumaSeed),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Kuma-sensei teaches; you do the thinking.',
            style: IunaText.body.copyWith(height: 1.35, color: IunaPalette.ink2),
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
                  style: IunaText.subtitle.copyWith(fontWeight: FontWeight.w800, color: IunaPalette.ink),
                ),
              ),
              if (s.chapterCount > 0)
                Text(
                  '${s.passedCount}/${s.chapterCount}',
                  style: IunaText.chip.copyWith(fontWeight: FontWeight.w700, color: IunaPalette.ink2),
                ),
              const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
            ],
          ),
          const SizedBox(height: 4),
          Text(line, style: IunaText.caption.copyWith(color: IunaPalette.ink3)),
          if (s.chapterCount > 0) ...[
            const SizedBox(height: 10),
            LearnProgressBar(done: s.passedCount, total: s.chapterCount),
          ],
        ],
      ),
    );
  }
}
