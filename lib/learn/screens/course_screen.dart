import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/iuna_page.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import '../../widgets/text_input_dialog.dart';
import '../../widgets/time_words.dart';
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
      destructive: true,
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
            Text(
              'What Kuma-sensei knows',
              style: IunaText.title.copyWith(color: IunaPalette.ink),
            ),
            const SizedBox(height: 4),
            Text(
              course.stateUpdatedAt == null
                  ? 'Nothing saved for this course yet.'
                  : 'Notes for this course, last saved ${dayWords(course.stateUpdatedAt!.toLocal())}.',
              style: IunaText.caption.copyWith(color: IunaPalette.ink3),
            ),
            if (course.stateMarkdown.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              LearnPanel(
                child: TutorMarkdown(
                  course.stateMarkdown,
                  fontSize: 13,
                  bookmarks: widget.env.bookmarks,
                ),
              ),
            ],
            const IunaSectionHeader(
              'Teaching preferences · every course',
              padding: EdgeInsets.fromLTRB(4, 18, 0, 8),
            ),
            LearnPanel(
              child: prefs.trim().isEmpty
                  ? Text(
                      'None yet. Kuma-sensei notes how you like to be taught as it learns.',
                      style: IunaText.bodySmall.copyWith(color: IunaPalette.ink3),
                    )
                  : TutorMarkdown(prefs, fontSize: 13, bookmarks: widget.env.bookmarks),
            ),
          ],
        ),
      ),
    );
  }

  void _lockedSnack() =>
      showSnack(context, 'Locked — pass the current chapter first.');

  @override
  Widget build(BuildContext context) {
    final course = _course;
    return IunaPage(
      title: course?.title ?? '',
      trailing: course == null
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Course options',
              icon: const Icon(Icons.more_vert_rounded),
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
      body: _loading || course == null
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
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 0),
                    child: Text(
                      'No chapters yet. They appear here once you agree on a plan in the room.',
                      style: IunaText.bodySmall.copyWith(height: 1.4, color: IunaPalette.ink3),
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
              style: IunaText.body.copyWith(height: 1.4, color: IunaPalette.ink2),
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
            style: IunaText.chip.copyWith(fontWeight: FontWeight.w700, color: IunaPalette.ink),
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
                style: IunaText.subtitle.copyWith(fontWeight: FontWeight.w700, color: IunaPalette.ink),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: IunaText.caption.copyWith(height: 1.35, color: IunaPalette.ink3),
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
    final (icon, iconColor, trailing, ink) = switch (chapter.status) {
      ChapterStatus.passed => (
        Icons.check_circle_rounded,
        IunaPalette.mintInk,
        'Revise',
        IunaPalette.mintInk,
      ),
      ChapterStatus.unlocked => (
        Icons.play_circle_fill_rounded,
        IunaPalette.ctaBottom,
        'Continue',
        IunaPalette.honeyInk,
      ),
      ChapterStatus.locked => (
        Icons.lock_rounded,
        IunaPalette.ink3,
        'Locked',
        IunaPalette.ink3,
      ),
    };
    return LearnPanel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: _RowTile(
        icon: icon,
        iconColor: iconColor,
        title: '${index + 1}. ${chapter.title}',
        subtitle: chapter.summary,
        trailing: Text(
          trailing,
          style: IunaText.chip.copyWith(fontWeight: FontWeight.w700, color: ink),
        ),
      ),
    );
  }
}
