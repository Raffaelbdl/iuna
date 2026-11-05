import 'dart:convert';

import 'package:flutter/material.dart' show Icons;

import '../../core/japanese_text.dart';
import '../deck.dart';
import 'tools.dart';

const int kMaxBookmarkWords = 20;

/// `会議（かいぎ）`: how the tutor writes a word in chat, so it may pass
/// one that way too.
final _withReading = RegExp(r'^(.+?)\s*[（(]\s*(.+?)\s*[）)]$');

/// The model's word list down to distinct `(word, reading)` pairs, all
/// checked before a single word is bookmarked. A kana word is its own
/// reading.
List<(String, String)> parseBookmarkWords(Object? raw) {
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } on FormatException {
      throw const ToolError('words must be a list of {word, reading}');
    }
  }
  if (raw is! List || raw.isEmpty) {
    throw const ToolError('words must be a non-empty list of {word, reading}');
  }
  if (raw.length > kMaxBookmarkWords) {
    throw const ToolError('at most $kMaxBookmarkWords words per call');
  }
  final out = <(String, String)>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    final given = item is Map ? item['word'] : item;
    if (given is! String || given.trim().isEmpty) {
      throw ToolError("word $i needs a non-empty 'word'");
    }
    var word = given.trim();
    var reading = item is Map ? '${item['reading'] ?? ''}'.trim() : '';
    final paren = _withReading.firstMatch(word);
    if (paren != null) {
      word = paren[1]!;
      if (reading.isEmpty) reading = paren[2]!;
    }
    if (reading.isEmpty) {
      if (kanjiChar.hasMatch(word)) throw ToolError("word $i: $word needs its kana 'reading'");
      reading = word;
    }
    if (!out.contains((word, reading))) out.add((word, reading));
  }
  return out;
}

class BookmarkWordsTool extends ChatTool {
  const BookmarkWordsTool(this.bookmarks);
  final WordBookmarks bookmarks;

  @override
  String get name => 'bookmark_words';

  @override
  String get runningLabel => 'Bookmarking…';

  /// Names only what was actually bookmarked: a word the learner owns
  /// is left alone, and so is the history.
  @override
  ToolActivity? activity(Map<String, dynamic> args, String result) {
    final words = _bookmarked(result);
    if (words.isEmpty) return null;
    final more = words.length > 3 ? ' +${words.length - 3}' : '';
    return ToolActivity(
      'Bookmarked · ${words.take(3).join(', ')}$more',
      Icons.bookmark_add_rounded,
    );
  }

  @override
  String get description =>
      "Bookmark words in the learner's card deck, so one of their next "
      'booster packs brings them, and their reviews follow.\n\n'
      'Give each word in its dictionary form as usually written (kanji when '
      'it has them) with its kana reading. A word already in their '
      'collection is left alone.\n\n'
      'Returns {"words": [{"word", "reading", "result"}]}, one entry per '
      'word. "not found" usually means a spelling the dictionary does not '
      'use: try the common written form.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'words': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'word': {
                  'type': 'string',
                  'description': 'dictionary form as usually written, e.g. 会議; kana for a kana word',
                },
                'reading': {
                  'type': 'string',
                  'description': 'its reading in kana, e.g. かいぎ; the word itself for a kana word',
                },
              },
              'required': ['word', 'reading'],
            },
          },
        },
        'required': ['words'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final words = parseBookmarkWords(args['words']);
    return jsonEncode({
      'words': [
        for (final (word, reading) in words)
          {
            'word': word,
            'reading': reading,
            'result': (await bookmarks.bookmark(word, reading)).wire,
          },
      ],
    });
  }
}

List<String> _bookmarked(String result) {
  final Object? decoded;
  try {
    decoded = jsonDecode(result);
  } on FormatException {
    return const [];
  }
  final words = decoded is Map ? decoded['words'] : null;
  if (words is! List) return const [];
  return [
    for (final w in words)
      if (w is Map && w['result'] == BookmarkOutcome.bookmarked.wire) '${w['word']}',
  ];
}
