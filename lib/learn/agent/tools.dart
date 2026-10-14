import 'package:flutter/widgets.dart';

import 'quiz.dart';

/// A refusal the model should read and adapt to. Becomes the tool
/// result `error: <message>`.
class ToolError implements Exception {
  const ToolError(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The tool result the model reads as a refusal.
String toolErrorResult(String message) => 'error: $message';

bool isToolError(String result) => result.startsWith('error:');

/// What the history shows once a tool ran.
class ToolActivity {
  const ToolActivity(this.label, this.icon, {this.tappable = false});

  final String label;
  final IconData icon;

  /// The host screen acts on a tap (e.g. opens the Theory tab).
  final bool tappable;
}

class ToolRunContext {
  const ToolRunContext({required this.askQuiz});

  /// Shows [QuizSpec] as a card and completes with the learner's answers
  /// (or `{"status": "cancelled"}` when they leave first).
  final Future<Map<String, dynamic>> Function(QuizSpec spec) askQuiz;
}

/// A tool the model can call. Besides the wire schema, each tool says
/// how it looks while running and afterwards, so the generic chat code
/// never has to know tool names.
abstract class ChatTool {
  const ChatTool();

  static const interruptedDefault =
      'error: interrupted — the app was closed before this finished';

  String get name;
  String get description;

  /// JSON schema of the arguments object.
  Map<String, dynamic> get parameters;

  Future<String> run(Map<String, dynamic> args, ToolRunContext context);

  /// Status line while the model is calling it.
  String get runningLabel => 'Working…';

  /// The chip left in the history once it ran; null leaves nothing.
  /// [result] is what [run] returned, for a chip that reports an outcome.
  ToolActivity? activity(Map<String, dynamic> args, String result) => null;

  /// A record of the call that replaces the [activity] chip, for a tool
  /// whose outcome is worth more than a line (the quiz and its answers).
  Widget? historyEntry(Map<String, dynamic> args, String result) => null;

  /// Recorded as its result when the app died before it finished.
  String get interruptedResult => interruptedDefault;

  Map<String, dynamic> toApi() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}
