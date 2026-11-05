import 'dart:convert';

import '../../db/repository.dart' show ExampleText;
import '../deck.dart';

/// Why a card got no examples or English, worded for the learner.
class ExampleWriterError implements Exception {
  const ExampleWriterError(this.message);
  final String message;

  @override
  String toString() => message;
}

const _noExamples = ExampleWriterError('Kuma-sensei replied without examples.');
const _noEnglish = ExampleWriterError('Kuma-sensei replied without translations.');

/// What the model is told about the card: the same facts the learner
/// sees on it.
String exampleBrief(FocusCard card) {
  final b = StringBuffer()
    ..writeln('Word: ${card.headword}')
    ..writeln('JLPT: ${card.jlptLabel}');
  if (card.senses.isNotEmpty) {
    b
      ..writeln('Senses:')
      ..writeln(card.numberedSenses());
  }
  return b.toString().trimRight();
}

/// The card, then the sentences it shows without English, numbered so
/// the reply can point at them without copying the Japanese back.
String translateBrief(FocusCard card, List<String> sentences) =>
    '${exampleBrief(card)}\n\nSentences:\n${numbered(sentences)}';

const int kMaxWrittenExamples = 5;

/// Reads the reply as the JSON array the brief asks for.
List<ExampleText> parseWrittenExamples(String reply) {
  final examples = <ExampleText>[];
  for (final item in _jsonArray(reply, _noExamples)) {
    if (item is! Map) continue;
    final ja = item['ja'];
    final en = item['en'];
    if (ja is! String || ja.trim().isEmpty) continue;
    examples.add((sentence: ja.trim(), translation: en is String ? en.trim() : ''));
    if (examples.length == kMaxWrittenExamples) break;
  }
  if (examples.isEmpty) throw _noExamples;
  return examples;
}

/// English by the 0-based index of the sentence it translates, out of
/// [count]; numbers outside the brief's are ignored.
Map<int, String> parseNumberedEnglish(String reply, int count) {
  final english = <int, String>{};
  for (final item in _jsonArray(reply, _noEnglish)) {
    if (item is! Map) continue;
    final n = item['n'];
    final en = item['en'];
    if (n is! num || n < 1 || n > count || en is! String || en.trim().isEmpty) continue;
    english[n.toInt() - 1] = en.trim();
  }
  if (english.isEmpty) throw _noEnglish;
  return english;
}

/// The JSON array in a reply, tolerating a code fence or a stray
/// sentence around it.
List<Object?> _jsonArray(String reply, ExampleWriterError none) {
  final start = reply.indexOf('[');
  final end = reply.lastIndexOf(']');
  if (start < 0 || end <= start) throw none;
  try {
    final decoded = jsonDecode(reply.substring(start, end + 1));
    return decoded is List ? decoded : throw none;
  } on FormatException {
    throw none;
  }
}
