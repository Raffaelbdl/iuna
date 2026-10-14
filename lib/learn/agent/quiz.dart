import 'dart:async';
import 'dart:convert';

import 'tools.dart';

const String kDefaultSkipLabel = "I don't know";
const int kMaxQuizQuestions = 8;

class QuizOption {
  const QuizOption({required this.id, required this.label});
  final String id;
  final String label;
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    this.options,
    this.allowMultiple = false,
  });

  final String id;
  final String prompt;

  /// Null for a free-text answer.
  final List<QuizOption>? options;
  final bool allowMultiple;
}

/// What the learner sees. Rebuilt field by field from the model's
/// arguments, so an answer key or explanation it attached never reaches
/// the card — the model keeps it and grades in the same turn.
class QuizSpec {
  const QuizSpec({
    required this.questions,
    this.title = '',
    this.note = '',
    this.skipLabel = kDefaultSkipLabel,
  });

  final List<QuizQuestion> questions;
  final String title;
  final String note;

  /// Every question offers it: a probe that forces a guess measures
  /// guessing, not knowledge.
  final String skipLabel;

  factory QuizSpec.parse(Map<String, dynamic> args) {
    Object? raw = args['questions'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } on FormatException {
        throw const ToolError('questions must be a list of {prompt, options?}');
      }
    }
    if (raw is! List || raw.isEmpty) {
      throw const ToolError('questions must be a non-empty list of {prompt, options?}');
    }
    if (raw.length > kMaxQuizQuestions) {
      throw const ToolError(
        'at most $kMaxQuizQuestions questions per card — one card, one retrieval target',
      );
    }
    final seen = <String>{};
    final questions = <QuizQuestion>[];
    for (var i = 0; i < raw.length; i++) {
      final q = raw[i];
      if (q is! Map) throw ToolError("question $i must be an object with a 'prompt'");
      final prompt = q['prompt'] ?? q['question'] ?? q['text'];
      if (prompt is! String || prompt.trim().isEmpty) {
        throw ToolError("question $i needs a non-empty 'prompt'");
      }
      var id = '${q['id'] ?? 'q$i'}'.trim();
      if (id.isEmpty || seen.contains(id)) id = 'q$i';
      seen.add(id);
      questions.add(QuizQuestion(
        id: id,
        prompt: prompt.trim(),
        options: _options(q['options'] ?? q['choices'], i),
        allowMultiple: q['allow_multiple'] == true,
      ));
    }
    final skip = '${args['skip_label'] ?? ''}'.trim();
    return QuizSpec(
      questions: questions,
      title: '${args['title'] ?? ''}'.trim(),
      note: '${args['note'] ?? ''}'.trim(),
      skipLabel: skip.isEmpty ? kDefaultSkipLabel : skip,
    );
  }

  static List<QuizOption>? _options(Object? raw, int question) {
    if (raw == null) return null;
    if (raw is! List || raw.isEmpty) {
      throw ToolError("question $question: 'options' must be a non-empty list when present");
    }
    final out = <QuizOption>[];
    for (var i = 0; i < raw.length; i++) {
      final o = raw[i];
      final label = o is String ? o : (o is Map ? (o['label'] ?? o['text']) : null);
      if (label is! String || label.trim().isEmpty) {
        throw ToolError('question $question, option $i needs a label');
      }
      out.add(QuizOption(id: 'o$i', label: label.trim()));
    }
    return out;
  }

  /// The tool result. Choices come back as their labels so the model
  /// can grade without mapping ids back.
  Map<String, dynamic> result({
    required Map<String, Set<String>> selected,
    required Map<String, String> text,
    required Set<String> skipped,
  }) {
    final values = <String, Object>{};
    for (final q in questions) {
      if (skipped.contains(q.id)) continue;
      final opts = q.options;
      if (opts == null) {
        values[q.id] = (text[q.id] ?? '').trim();
      } else {
        final ids = selected[q.id] ?? const <String>{};
        values[q.id] = [
          for (final o in opts)
            if (ids.contains(o.id)) o.label,
        ];
      }
    }
    return {
      'status': 'answered',
      'values': values,
      'skipped': [
        for (final q in questions)
          if (skipped.contains(q.id)) q.id,
      ],
    };
  }
}

class PendingQuiz {
  PendingQuiz(this.spec);

  final QuizSpec spec;
  final _done = Completer<Map<String, dynamic>>();

  Future<Map<String, dynamic>> get future => _done.future;

  void complete(Map<String, dynamic> result) {
    if (!_done.isCompleted) _done.complete(result);
  }
}
