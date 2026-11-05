import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/database.dart';
import '../../screens/app_nav.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/hex_bg.dart';
import '../../widgets/iuna_bottom_nav.dart';
import '../../widgets/kuma_mascot.dart';
import '../../widgets/notice.dart';
import '../../widgets/section_header.dart';
import '../../widgets/tab_header.dart';
import '../db/learn_repository.dart';
import '../learn.dart';
import '../widgets/ask_bar.dart';
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

class _LearnScreenState extends State<LearnScreen> with LoadGate {
  late final LearnEnv _env = widget.env ?? LearnEnv.live(widget.db);
  List<CourseSummary> _courses = const [];
  StreamSubscription<int>? _changes;

  @override
  void initState() {
    super.initState();
    load();
    _changes = _env.repo.changes.listen((_) => _loadIfShown());
  }

  /// Under a course the tutor writes at every step; [_openCourse]
  /// reloads once it pops instead.
  void _loadIfShown() {
    if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  @override
  Future<void> load() async {
    final courses = await guardLoad('Learn', _env.repo.courseSummaries);
    if (courses == null || !mounted) return;
    showLoaded(() => _courses = courses);
  }

  Future<void> _openCourse(int id, {bool openRoom = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CourseScreen(env: _env, courseId: id, openRoomOnStart: openRoom),
    ));
    if (mounted) await load();
  }

  Future<void> _resumeAsk() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AskScreen.resume(env: _env),
    ));
    if (mounted) setState(() {});
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
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        const IunaTabHeader('Learn'),
                        Expanded(
                          child: failed
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: AskBar.inset),
                                  child: LoadErrorNotice(onRetry: retry),
                                )
                              : _courseList(),
                        ),
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
                hint: 'Ask Kuma-sensei about Japanese…',
                onReturn: () => setState(() {}),
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
        if (LastAskChat.of(_env)?.preview case final question?) ...[
          const SizedBox(height: 14),
          _LastAskTile(question: question, onTap: _resumeAsk),
        ],
        IunaSectionHeader(
          'Courses',
          padding: const EdgeInsets.fromLTRB(4, 18, 0, 8),
          trailing: TextButton.icon(
            onPressed: _newCourse,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New course'),
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

/// The way back into the last Ask chat, kept for the app session.
class _LastAskTile extends StatelessWidget {
  const _LastAskTile({required this.question, required this.onTap});

  final String question;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LearnPanel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.forum_rounded, color: IunaPalette.honeyInk, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Back to your last question',
                  style: IunaText.label.copyWith(fontWeight: FontWeight.w700, color: IunaPalette.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IunaText.caption.copyWith(color: IunaPalette.ink3),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
        ],
      ),
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
