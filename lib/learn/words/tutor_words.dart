import 'package:flutter/scheduler.dart';

import '../../db/jmdict_lookup.dart';
import '../../core/japanese_text.dart';
import 'segmenter.dart';

/// The words of the tutor's messages, read against the dictionary
/// sidecar so the learner can tap one for its reading and meaning.
class TutorWords {
  TutorWords({Future<WordLexicon?> Function()? lexicon}) : _lexicon = lexicon ?? _sidecar;

  /// Swapped in tests, as [LearnSettings.instance] is.
  static TutorWords instance = TutorWords();

  final Future<WordLexicon?> Function() _lexicon;
  // Insertion-ordered, so the first key is the least recently used.
  final _cache = <String, Map<String, List<TextWord>>>{};

  static const _cacheSize = 64;

  /// Whether there is a dictionary to read words with.
  Future<bool> available() async => await _lexiconOrNull() != null;

  // Best-effort: the lookups are an aid, and a dictionary that fails to
  // open must not break the chat around them.
  Future<WordLexicon?> _lexiconOrNull() async {
    try {
      return await _lexicon();
    } catch (_) {
      return null;
    }
  }

  static Future<WordLexicon?> _sidecar() async {
    final dictionary = JmdictLookup.instance;
    await dictionary.warmUp();
    return dictionary.isOpen ? dictionary.byForms : null;
  }

  /// The words of [text] if it was read before, so a bubble scrolled
  /// back into view doesn't flash plain first.
  Map<String, List<TextWord>>? cached(String text) {
    final hit = _cache.remove(text);
    if (hit != null) _cache[text] = hit;
    return hit;
  }

  /// The words of [text], keyed by Japanese run; null without a
  /// dictionary. Bubbles asking for the same text share one read.
  Future<Map<String, List<TextWord>>?> read(String text) {
    final hit = cached(text);
    if (hit != null) return Future.value(hit);
    if (!japaneseRun.hasMatch(text)) return Future.value(const {});
    return _pending[text] ??= _queued(text).whenComplete(() {
      _pending.remove(text);
    });
  }

  final _pending = <String, Future<Map<String, List<TextWord>>?>>{};
  Future<void> _tail = Future.value();

  // A read runs on the UI thread. One per frame, in order, so a
  // screenful of bubbles mounting together doesn't stall one frame.
  Future<Map<String, List<TextWord>>?> _queued(String text) {
    final done = _tail.then((_) => SchedulerBinding.instance.endOfFrame).then((_) => _read(text));
    _tail = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<Map<String, List<TextWord>>?> _read(String text) async {
    final lexicon = await _lexiconOrNull();
    if (lexicon == null) return null;
    final words = readText(text, lexicon);
    _cache[text] = words;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return words;
  }
}
