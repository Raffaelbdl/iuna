import 'dart:convert';

import 'quiz.dart';

/// A multiple-choice question the tutor asked in chat: its message carries
/// a fenced `choices` block, one option per line (the contract the model
/// reads is `assets/learn/prompts/choices.md`). The view turns the options
/// into buttons and a tap sends one back as the learner's reply, so the
/// question stays an ordinary turn the next one can adapt to.
class ChatChoices {
  const ChatChoices({required this.text, required this.options});

  /// The message without its block.
  final String text;

  /// Empty while the block is still streaming in.
  final List<String> options;

  static final _open = RegExp(r'^\s*(`{3,}|~{3,})\s*choices\s*$', caseSensitive: false);
  static final _bullet = RegExp(r'^[-*+]\s+');

  /// Null when [content] has no `choices` block. The last block wins, and
  /// an unclosed one runs to the end — which is also what a reply still
  /// streaming looks like.
  static ChatChoices? parse(String content) {
    final lines = const LineSplitter().convert(content);
    var start = -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (_open.hasMatch(lines[i])) {
        start = i;
        break;
      }
    }
    if (start < 0) return null;
    final fence = _open.firstMatch(lines[start])!.group(1)!;
    var end = lines.length;
    for (var i = start + 1; i < lines.length; i++) {
      if (_closes(lines[i].trim(), fence)) {
        end = i;
        break;
      }
    }
    final skip = _fold(kDefaultSkipLabel);
    final options = <String>[];
    for (final line in lines.sublist(start + 1, end)) {
      final option = line.trim().replaceFirst(_bullet, '').trim();
      // The view always offers its own "I don't know".
      if (option.isEmpty || _fold(option) == skip || options.contains(option)) continue;
      options.add(option);
    }
    final text = [
      ...lines.sublist(0, start),
      if (end < lines.length) ...lines.sublist(end + 1),
    ].join('\n').trim();
    return ChatChoices(text: text, options: options);
  }

  static bool _closes(String line, String fence) =>
      line.length >= fence.length && line.split('').every((c) => c == fence[0]);

  static String _fold(String s) => s.replaceAll('’', "'").toLowerCase();
}
