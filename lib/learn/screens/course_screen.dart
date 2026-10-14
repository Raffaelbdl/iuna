import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/text_input_dialog.dart';
import '../agent/tutor_prompt.dart' show isoDay;
import '../db/learn_database.dart';
import '../learn.dart';
import '../widgets/tutor_markdown.dart';
import 'learn_widgets.dart';
import 'tutor_chat_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({
    super.key,
    required this.env,
    required this.courseId,
    this.openRoomOnStart = false,
  });

  final LearnEnv env;
  final int courseId;

  /// Straight into the room after creating a course: that is where it
  /// starts.
  final bool openRoomOnStart;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  CourseRow? _course;
  List<ChapterRow> _chapters = const [];
  bool _loading = true;
  StreamSubscription<int>? _changes;

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.openRoomOnStart && mounted && _course != null) _openRoom();
    });
    _changes = widget.env.repo.changes
        .where((id) => id == widget.courseId)
        .listen((_) => _loadIfShown());
  }

  /// Under a lesson the tutor writes at every step; [_open] reloads once
  /// it pops instead.
  void _loadIfShown() {
    if (mounted && (ModalRoute.isCurrentOf(context) ?? true)) _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = widget.env.repo;
    final course = await repo.course(widget.courseId);
    final chapters = await repo.chapters(widget.courseId);
    if (!mounted) return;
    setState(() {
      _course = course;
      _chapters = chapters;
      _loading = false;
    });
  }

  Future<void> _open(String? chapterKey) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TutorChatScreen(
        env: widget.env,
        courseId: widget.courseId,
        chapterKey: chapterKey,
      ),
    ));
    if (mounted) await _load();
  }

  void _openRoom() => _open(null);

  Future<void> _rename() async {
    final result = await showTextInputDialog(
      context,
      title: 'Rename course',
      initial: _course?.title ?? '',
      confirmLabel: 'Rename',
    );
    if (result == null || result.text.isEmpty) return;
    await widget.env.repo.renameCourse(widget.courseId, result.text);
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete “${_course?.title ?? ''}”?',
      body:
          'Its chapters, theory, chats and Kuma-sensei’s notes are removed '
          'from this phone. Drive backups keep their own copy.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await widget.env.repo.deleteCourse(widget.courseId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showNotes() async {
    final prefs = await widget.env.repo.preferences();
    if (!mounted) return;
    final course = _course!;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: IunaPalette.bg,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text(
              'What Kuma-sensei knows',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: IunaPalette.ink),
            ),
            const SizedBox(height: 4),
            Text(
              course.stateUpdatedAt == null
                  ? 'Nothing saved for this course yet.'
                  : 'Notes for this course, last saved ${isoDay(course.stateUpdatedAt!.toLocal())}.',
              style: const TextStyle(fontSize: 12, color: IunaPalette.ink3),
            ),
            if (course.stateMarkdown.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              LearnPanel(child: TutorMarkdown(course.stateMarkdown, fontSize: 13)),
            ],
            const IunaSectionHeader(
              'Teaching preferences · every course',
              padding: EdgeInsets.fromLTRB(4, 18, 0, 8),
            ),
            LearnPanel(
              child: prefs.trim().isEmpty
                  ? const Text(
                      'None yet. Kuma-sensei notes how you like to be taught as it learns.',
                      style: TextStyle(fontSize: 13, color: IunaPalette.ink3),
                    )
                  : TutorMarkdown(prefs, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _lockedSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Locked — pass the current chapter first.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = _course;
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      appBar: AppBar(
        title: Text(course?.title ?? ''),
        actions: [
          if (course != null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'notes' => _showNotes(),
                'rename' => _rename(),
                'delete' => _delete(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'notes', child: Text('What Kuma-sensei knows')),
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'delete', child: Text('Delete course')),
              ],
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: _loading || course == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _Header(course: course, chapters: _chapters),
                  const SizedBox(height: 12),
                  LearnPanel(
                    onTap: _openRoom,
                    child: _RowTile(
                      icon: Icons.forum_rounded,
                      iconColor: IunaPalette.ctaBottom,
                      title: 'Course room',
                      subtitle: _chapters.isEmpty
                          ? 'Start here: Kuma-sensei checks what you already know, then proposes a plan.'
                          : 'Re-plan, questions across chapters, homework.',
                    ),
                  ),
                  const IunaSectionHeader(
                    'Chapters',
                    padding: EdgeInsets.fromLTRB(4, 18, 0, 8),
                  ),
                  if (_chapters.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: Text(
                        'No chapters yet. They appear here once you agree on a plan in the room.',
                        style: TextStyle(fontSize: 13, height: 1.4, color: IunaPalette.ink3),
                      ),
                    ),
                  for (var i = 0; i < _chapters.length; i++) ...[
                    _ChapterTile(
                      index: i,
                      chapter: _chapters[i],
                      onTap: _chapters[i].status == ChapterStatus.locked
                          ? _lockedSnack
                          : () => _open(_chapters[i].key),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.course, required this.chapters});

  final CourseRow course;
  final List<ChapterRow> chapters;

  @override
  Widget build(BuildContext context) {
    final passed = chapters.where((c) => c.status == ChapterStatus.passed).length;
    return LearnPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.goal.isNotEmpty) ...[
            Text(
              course.goal,
              style: const TextStyle(fontSize: 14, height: 1.4, color: IunaPalette.ink2),
            ),
            const SizedBox(height: 12),
          ],
          LearnProgressBar(done: passed, total: chapters.length),
          const SizedBox(height: 8),
          Text(
            chapters.isEmpty
                ? 'Not planned yet'
                : passed == chapters.length
                    ? 'All $passed chapters passed 完'
                    : '$passed of ${chapters.length} chapters passed',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: IunaPalette.ink),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 26),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: IunaPalette.ink),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.35, color: IunaPalette.ink3),
                ),
              ],
            ],
          ),
        ),
        trailing ?? const Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3),
      ],
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.index, required this.chapter, required this.onTap});

  final int index;
  final ChapterRow chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color, trailing) = switch (chapter.status) {
      ChapterStatus.passed => (Icons.check_circle_rounded, const Color(0xFF7FBFA3), 'Revise'),
      ChapterStatus.unlocked => (Icons.play_circle_fill_rounded, IunaPalette.ctaBottom, 'Continue'),
      ChapterStatus.locked => (Icons.lock_rounded, IunaPalette.inkMute, ''),
    };
    final locked = chapter.status == ChapterStatus.locked;
    return Opacity(
      opacity: locked ? 0.6 : 1,
      child: LearnPanel(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: _RowTile(
          icon: icon,
          iconColor: color,
          title: '${index + 1}. ${chapter.title}',
          subtitle: chapter.summary,
          trailing: trailing.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  trailing,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
        ),
      ),
    );
  }
}
