import 'package:flutter/material.dart';

import '../../theme/iuna_theme.dart';
import '../agent/quiz.dart';
import 'tutor_markdown.dart';

BoxDecoration _cardDecoration({bool live = false}) => paperPanelDecoration(
      border: live ? Border.all(color: IunaPalette.bellGold, width: 1.2) : null,
    );

class _QuizHeader extends StatelessWidget {
  const _QuizHeader({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.quiz_rounded, size: 18, color: IunaPalette.ctaBottom),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: IunaPalette.ink,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// The card `ask_quiz` puts in front of the learner. Submits only once
/// every question is answered or explicitly skipped.
class QuizCard extends StatefulWidget {
  const QuizCard({super.key, required this.spec, required this.onSubmit});

  final QuizSpec spec;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  final Map<String, Set<String>> _selected = {};
  final Map<String, TextEditingController> _text = {};
  final Set<String> _skipped = {};
  bool _sent = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String id) =>
      _text.putIfAbsent(id, () => TextEditingController()..addListener(() => setState(() {})));

  bool _answered(QuizQuestion q) {
    if (_skipped.contains(q.id)) return true;
    if (q.options == null) return _controllerFor(q.id).text.trim().isNotEmpty;
    return (_selected[q.id] ?? const {}).isNotEmpty;
  }

  void _toggle(QuizQuestion q, String optionId) {
    setState(() {
      _skipped.remove(q.id);
      final set = _selected.putIfAbsent(q.id, () => <String>{});
      if (q.allowMultiple) {
        if (!set.remove(optionId)) set.add(optionId);
      } else {
        set
          ..clear()
          ..add(optionId);
      }
    });
  }

  void _submit() {
    setState(() => _sent = true);
    widget.onSubmit(widget.spec.result(
      selected: _selected,
      text: {for (final e in _text.entries) e.key: e.value.text},
      skipped: _skipped,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final ready = !_sent && spec.questions.every(_answered);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: _cardDecoration(live: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuizHeader(title: spec.title.isEmpty ? 'Quick check' : spec.title),
          if (spec.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            TutorMarkdown(spec.note, fontSize: 13),
          ],
          for (var i = 0; i < spec.questions.length; i++) ...[
            const SizedBox(height: 14),
            _question(i, spec.questions[i], spec.skipLabel),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: ready ? _submit : null,
              child: Text(_sent ? 'Sent' : 'Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _question(int index, QuizQuestion q, String skipLabel) {
    final skipped = _skipped.contains(q.id);
    final options = q.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: IunaPalette.ink3,
                height: 1.5,
              ),
            ),
            Expanded(child: TutorMarkdown(q.prompt, selectable: false)),
          ],
        ),
        const SizedBox(height: 6),
        if (options == null)
          TextField(
            controller: _controllerFor(q.id),
            enabled: !skipped && !_sent,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontSize: 14, color: IunaPalette.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Your answer',
              hintStyle: const TextStyle(color: IunaPalette.inkMute),
              filled: true,
              fillColor: IunaPalette.paper2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(IunaRadii.sm),
                borderSide: BorderSide.none,
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(o.label),
                  selected: (_selected[q.id] ?? const {}).contains(o.id),
                  onSelected: _sent ? null : (_) => _toggle(q, o.id),
                  selectedColor: const Color(0xFFFDE9C9),
                  backgroundColor: IunaPalette.paper2,
                  labelStyle: const TextStyle(fontSize: 14, color: IunaPalette.ink),
                  showCheckmark: q.allowMultiple,
                  side: const BorderSide(color: Color.fromRGBO(74, 53, 32, 0.12)),
                ),
            ],
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _sent
                ? null
                : () => setState(() {
                      if (!_skipped.remove(q.id)) _skipped.add(q.id);
                    }),
            icon: Icon(
              skipped ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              size: 16,
            ),
            label: Text(skipLabel),
            style: TextButton.styleFrom(
              foregroundColor: skipped ? IunaPalette.ink : IunaPalette.ink3,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
              textStyle: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ],
    );
  }
}

/// A quiz already answered (or abandoned), as it stays in the history.
class QuizRecordCard extends StatelessWidget {
  const QuizRecordCard({super.key, required this.spec, required this.result});

  final QuizSpec spec;

  /// The tool result, or null when it never came back.
  final Map<String, dynamic>? result;

  @override
  Widget build(BuildContext context) {
    final answered = result?['status'] == 'answered';
    final values = (result?['values'] as Map?) ?? const {};
    final skipped = ((result?['skipped'] as List?) ?? const []).toSet();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuizHeader(
            title: spec.title.isEmpty ? 'Quick check' : spec.title,
            trailing: Text(
              answered ? 'answered' : 'not answered',
              style: const TextStyle(fontSize: 11, color: IunaPalette.ink3),
            ),
          ),
          for (var i = 0; i < spec.questions.length; i++) ...[
            const SizedBox(height: 8),
            Text(
              '${i + 1}. ${spec.questions[i].prompt}',
              style: const TextStyle(fontSize: 13, color: IunaPalette.ink2, height: 1.4),
            ),
            if (answered)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Text(
                  skipped.contains(spec.questions[i].id)
                      ? spec.skipLabel
                      : _answerText(values[spec.questions[i].id]),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IunaPalette.ink,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _answerText(Object? value) {
    if (value is List) return value.join(', ');
    return '${value ?? ''}';
  }
}
