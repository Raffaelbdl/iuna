import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../widgets/quiz_card.dart';
import 'quiz.dart';
import 'tools.dart';

class AskQuizTool extends ChatTool {
  const AskQuizTool();

  @override
  String get name => 'ask_quiz';

  @override
  String get runningLabel => 'Preparing a quiz…';

  @override
  String get interruptedResult => jsonEncode({
        'status': 'cancelled',
        'reason': 'the app was closed before the learner answered',
      });

  @override
  String get description =>
      'Ask the learner questions in an interactive card and wait for the answers.\n\n'
      'Returns their raw answers — YOU grade them, in this same turn. Never put '
      'the correct answer, an explanation, or a score in `questions`: anything '
      'beyond prompt/options is stripped, and the point is that the learner '
      'cannot see the key.\n\n'
      'Every question always offers an opt-out ("I don\'t know"), so a blank is '
      'distinguishable from a guess — treat a skip as information, not failure.\n\n'
      'Returns {"status": "answered", "values": {question_id: [chosen option '
      'labels] | "free text"}, "skipped": [question_id]}, or {"status": '
      '"cancelled"} if the learner left. Use it for a fixed batch decided in '
      'advance (a revisit, an end-of-chapter check); probe an unknown edge in '
      'chat instead, one question per message (a `choices` block when it is '
      'multiple choice). A few questions per card, not twenty: one card, one '
      'retrieval target.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'questions': {
            'type': 'array',
            'description': 'Omit options for a free-text answer.',
            'items': {
              'type': 'object',
              'properties': {
                'id': {'type': 'string'},
                'prompt': {'type': 'string', 'description': 'Markdown.'},
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'allow_multiple': {'type': 'boolean'},
              },
              'required': ['prompt'],
            },
          },
          'title': {'type': 'string', 'description': "Short heading, e.g. 'Quick check'."},
          'note': {'type': 'string', 'description': 'Optional markdown shown above the questions.'},
          'skip_label': {'type': 'string', 'description': 'Wording of the opt-out on every question.'},
        },
        'required': ['questions'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final spec = QuizSpec.parse(args);
    return jsonEncode(await context.askQuiz(spec));
  }

  @override
  Widget? historyEntry(Map<String, dynamic> args, String result) {
    final QuizSpec spec;
    try {
      spec = QuizSpec.parse(args);
    } catch (_) {
      return null;
    }
    Map<String, dynamic>? answers;
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map<String, dynamic>) answers = decoded;
    } on FormatException {
      answers = null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: QuizRecordCard(spec: spec, result: answers),
    );
  }
}
