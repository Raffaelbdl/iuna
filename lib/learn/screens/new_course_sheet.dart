import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../db/learn_database.dart';
import '../db/learn_repository.dart';

Future<CourseRow?> showNewCourseSheet(BuildContext context, LearnRepository repo) {
  return showModalBottomSheet<CourseRow>(
    context: context,
    isScrollControlled: true,
    backgroundColor: IunaPalette.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(IunaRadii.xl)),
    ),
    builder: (_) => _NewCourseSheet(repo: repo),
  );
}

class _NewCourseSheet extends StatefulWidget {
  const _NewCourseSheet({required this.repo});

  final LearnRepository repo;

  @override
  State<_NewCourseSheet> createState() => _NewCourseSheetState();
}

class _NewCourseSheetState extends State<_NewCourseSheet> {
  final _title = TextEditingController();
  final _goal = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _goal.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    final course = await widget.repo.createCourse(title: _title.text, goal: _goal.text);
    if (!mounted) return;
    Navigator.of(context).pop(course);
  }

  InputDecoration _field(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: IunaPalette.inkMute),
        filled: true,
        fillColor: IunaPalette.paper2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(IunaRadii.md),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New course',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: IunaPalette.ink),
          ),
          const SizedBox(height: 6),
          const Text(
            'Name it after what you want to be able to do. Kuma-sensei pins '
            'down the goal with you in the course room, then checks what you '
            'already know before planning anything.',
            style: TextStyle(fontSize: 13, height: 1.4, color: IunaPalette.ink3),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: _field('Course', 'e.g. JLPT N1, Business Japanese'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goal,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: _field(
              'Anything to add? (optional)',
              'e.g. "pass N1 in December", "write polite emails to clients"',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _title.text.trim().isEmpty || _saving ? null : _create,
                child: const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
