import 'dart:convert';

import 'package:flutter/material.dart' show Icons;

import '../db/learn_repository.dart';
import 'ask_quiz_tool.dart';
import 'bookmark_tool.dart';
import 'tools.dart';

/// state.md is re-sent on every turn; past this it has stopped being a
/// distillation.
const int kMaxStateChars = 24000;
const int _maxChapters = 60;
const int _maxTitle = 120;
const int _maxSummary = 300;
final _chapterId = RegExp(r'^[a-z0-9][a-z0-9-]{0,40}$');

/// Validates the model's proposed chapters down to key/title/summary. A
/// `status` it attached is ignored: status is derived, never declared.
List<ChapterDraft> normalizeChapters(Object? raw) {
  if (raw is String) {
    try {
      raw = jsonDecode(raw);
    } on FormatException {
      throw const ToolError('chapters must be a list of {id, title, summary?}');
    }
  }
  if (raw is! List || raw.isEmpty) {
    throw const ToolError('chapters must be a non-empty list of {id, title, summary?}');
  }
  if (raw.length > _maxChapters) {
    throw const ToolError('at most $_maxChapters chapters; plan the next stretch later');
  }
  final out = <ChapterDraft>[];
  final seen = <String>{};
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) {
      throw ToolError("chapter $i must be an object with an 'id' and a 'title'");
    }
    final id = '${item['id'] ?? ''}'.trim();
    if (!_chapterId.hasMatch(id)) {
      throw ToolError(
        "chapter $i: id '$id' must be lowercase letters, digits and dashes, "
        'starting with a letter or digit, max 41 chars',
      );
    }
    if (!seen.add(id)) throw ToolError("duplicate chapter id '$id'");
    final title = '${item['title'] ?? ''}'.trim();
    if (title.isEmpty) throw ToolError("chapter $id: 'title' must be non-empty");
    if (title.length > _maxTitle) {
      throw ToolError("chapter $id: 'title' is longer than $_maxTitle chars");
    }
    final summary = '${item['summary'] ?? ''}'.trim();
    if (summary.length > _maxSummary) {
      throw ToolError("chapter $id: 'summary' is longer than $_maxSummary chars");
    }
    out.add(ChapterDraft(key: id, title: title, summary: summary));
  }
  return out;
}

/// The repository enforces the course rules; a refusal reaches the model
/// as a tool error it can read and adapt to.
Future<T> _rules<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on LearnRuleError catch (e) {
    throw ToolError(e.message);
  }
}

/// Where a tool call happens: which course, and the room or one lesson.
class TutorScope {
  const TutorScope({
    required this.repo,
    required this.courseId,
    required this.sessionKey,
  });

  final LearnRepository repo;
  final int courseId;
  final String sessionKey;

  bool get inRoom => sessionKey == kRoomSessionKey;

  String? get lessonChapter => chapterKeyOf(sessionKey);
}

List<ChatTool> tutorTools(TutorScope scope, {WordBookmarks? bookmarks}) => [
      CoursePlanTool(scope),
      CourseWriteTool(scope),
      CoursePassTool(scope),
      const AskQuizTool(),
      SaveStateTool(scope),
      SavePreferenceTool(scope),
      if (bookmarks != null) BookmarkWordsTool(bookmarks),
    ];

String _chapterArg(Map<String, dynamic> args) => '${args['chapter'] ?? ''}'.trim();

class CoursePlanTool extends ChatTool {
  const CoursePlanTool(this.scope);
  final TutorScope scope;

  @override
  String get name => 'course_plan';

  @override
  String get runningLabel => 'Drawing up the plan…';

  @override
  ToolActivity activity(Map<String, dynamic> args, String result) {
    Object? chapters = args['chapters'];
    if (chapters is String) {
      try {
        chapters = jsonDecode(chapters);
      } on FormatException {
        chapters = null;
      }
    }
    return ToolActivity(
      chapters is List ? 'Plan updated · ${chapters.length} chapters' : 'Plan updated',
      Icons.map_rounded,
    );
  }

  @override
  String get description =>
      'Register the chapters of this course, in teaching order.\n\n'
      'Call this once the learner has agreed to the plan you showed them, and '
      'again whenever the plan really changes. Chapters are session-sized: one '
      "per milestone boundary, ending on the cluster's challenge.\n\n"
      'Statuses are NOT yours to set — the app derives them: the first '
      'non-passed chapter is unlocked, later ones are locked, and anything '
      'already passed stays passed across a re-plan. Chapters you leave out '
      'are dropped from the list (their theory is kept). Course room only.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'chapters': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'id': {
                  'type': 'string',
                  'description': 'lowercase letters, digits and dashes, e.g. te-form-requests',
                },
                'title': {'type': 'string', 'description': 'what the learner sees'},
                'summary': {'type': 'string', 'description': 'one line'},
              },
              'required': ['id', 'title'],
            },
          },
        },
        'required': ['chapters'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    if (!scope.inRoom) {
      throw const ToolError(
        'planning happens in the course room, not in a lesson. Finish this '
        'step, then tell the learner to open the room from the course screen.',
      );
    }
    final drafts = normalizeChapters(args['chapters']);
    final rows = await _rules(() => scope.repo.applyPlan(scope.courseId, drafts));
    final lines = [
      for (var i = 0; i < rows.length; i++)
        '${i + 1}. ${rows[i].key} — ${rows[i].title} [${rows[i].status.name}]',
    ];
    return 'course registered:\n${lines.join('\n')}';
  }
}

class CourseWriteTool extends ChatTool {
  const CourseWriteTool(this.scope);
  final TutorScope scope;

  @override
  String get name => 'course_write';

  @override
  String get runningLabel => 'Writing the theory…';

  @override
  ToolActivity activity(Map<String, dynamic> args, String result) =>
      const ToolActivity('Added to the theory', Icons.menu_book_rounded, tappable: true);

  @override
  String get description =>
      "Append a section of theory to the chapter this lesson teaches.\n\n"
      "This is the text the learner keeps and revises from, shown in the "
      "chapter's Theory tab. Write the step's idea here FIRST, then explain it "
      'in chat — the document is the reference, the conversation is the '
      'teaching. One idea per section, self-contained, with the examples and '
      'tables it needs (markdown; no LaTeX, no diagrams).\n\n'
      "Append-only: a chapter's theory grows to fit the learner and is never "
      'rewritten. Once the chapter is passed it is frozen and this tool '
      'refuses — explain in chat instead, or note it in state.md.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'chapter': {'type': 'string', 'description': 'the chapter id this theory belongs to'},
          'markdown': {'type': 'string', 'description': 'one self-contained section of theory'},
        },
        'required': ['chapter', 'markdown'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final chapter = _chapterArg(args);
    final lesson = scope.lessonChapter;
    if (lesson == null) {
      throw const ToolError(
        "theory is written in the chapter's own lesson, not in the room. "
        'Point the learner at the chapter on the course screen.',
      );
    }
    if (chapter != lesson) {
      throw ToolError("this session is the lesson for '$lesson'; write only its theory here");
    }
    final body = '${args['markdown'] ?? ''}';
    await _rules(() => scope.repo.appendChapterDoc(scope.courseId, chapter, body));
    return 'appended ${body.trim().length} chars to the theory of $chapter';
  }
}

class CoursePassTool extends ChatTool {
  const CoursePassTool(this.scope);
  final TutorScope scope;

  @override
  String get name => 'course_pass';

  @override
  String get runningLabel => 'Marking the chapter passed…';

  @override
  ToolActivity activity(Map<String, dynamic> args, String result) =>
      const ToolActivity('Chapter passed', Icons.verified_rounded);

  @override
  String get description =>
      'Mark the chapter being taught as passed, which freezes its theory and '
      'unlocks the next one.\n\n'
      "Call this only after the chapter's final check or challenge succeeded. "
      'Then run the session-end protocol: save_state before the summary, always.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'chapter': {'type': 'string', 'description': 'the chapter id the learner just completed'},
        },
        'required': ['chapter'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final chapter = _chapterArg(args);
    final lesson = scope.lessonChapter;
    if (lesson != null && chapter != lesson) {
      throw ToolError("this session is the lesson for '$lesson'; only it can be passed here");
    }
    final next = await _rules(() => scope.repo.passChapter(scope.courseId, chapter));
    if (next == null) return '$chapter passed — course complete, every chapter is done';
    return '$chapter passed and frozen; ${next.key} — ${next.title} is now unlocked. '
        'Run the session-end protocol: save_state before the summary.';
  }
}

class SaveStateTool extends ChatTool {
  const SaveStateTool(this.scope);
  final TutorScope scope;

  @override
  String get name => 'save_state';

  @override
  String get runningLabel => 'Taking notes…';

  @override
  ToolActivity activity(Map<String, dynamic> args, String result) =>
      const ToolActivity('Notes saved', Icons.edit_note_rounded);

  @override
  String get description =>
      "Rewrite this course's state.md — your entire memory of the learner for "
      'this course, shown to you at the start of every session.\n\n'
      'It replaces the whole document: include everything still true (the map '
      'with dates and honest downgrades, the plan and position, the agenda and '
      'revisit counters, homework, the misconception log). Call it at every '
      'session end BEFORE the summary, and after any recalibration. Keep it '
      'under $kMaxStateChars chars; fenced YAML for dates and counters.';

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'markdown': {'type': 'string', 'description': 'the complete new state.md'},
        },
        'required': ['markdown'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final markdown = '${args['markdown'] ?? ''}'.trim();
    if (markdown.isEmpty) throw const ToolError("'markdown' is empty; write the whole state.md");
    if (markdown.length > kMaxStateChars) {
      throw ToolError(
        'state.md would be ${markdown.length} chars; keep it under $kMaxStateChars '
        '— it is re-sent every turn. Distill it.',
      );
    }
    await _rules(() => scope.repo.saveState(scope.courseId, markdown));
    return 'state.md saved (${markdown.length} chars)';
  }
}

class SavePreferenceTool extends ChatTool {
  const SavePreferenceTool(this.scope);
  final TutorScope scope;

  @override
  String get name => 'save_preference';

  @override
  String get runningLabel => 'Noting a preference…';

  @override
  ToolActivity activity(Map<String, dynamic> args, String result) =>
      const ToolActivity('Preference noted', Icons.lightbulb_rounded);

  @override
  String get description =>
      'Record a teaching preference that holds across every course, with its '
      "evidence and the date (e.g. 'prefers example-first explanations — asked "
      "for an example three times [2026-09-10]'). Declared preferences apply "
      'at once; revealed ones after 2-3 observations. Never store one that '
      "degrades the method itself (e.g. 'skip the checks').";

  @override
  Map<String, dynamic> get parameters => {
        'type': 'object',
        'properties': {
          'preference': {'type': 'string'},
        },
        'required': ['preference'],
      };

  @override
  Future<String> run(Map<String, dynamic> args, ToolRunContext context) async {
    final added = await _rules(() => scope.repo.addPreference('${args['preference'] ?? ''}'));
    return added ? 'preference saved (shared by every course)' : 'already saved, not added again';
  }
}
