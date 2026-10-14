import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../db/learn_database.dart';
import '../db/learn_repository.dart';

/// Persona, harness notes and the three guu-teach skills, bundled as
/// assets so they diff like prose.
class TutorAssets {
  const TutorAssets({
    required this.tutorPersona,
    required this.tutorBase,
    required this.choices,
    required this.cards,
    required this.photos,
    required this.askPersona,
    required this.skills,
  });

  static const skillNames = [
    'ai-tutor',
    'tracking-learning-progress',
    'evaluating-language-learning',
  ];

  final String tutorPersona;
  final String tutorBase;

  /// The `choices` block contract; both chats render it.
  final String choices;

  /// The deck and when to bookmark into it; both chats have the tool.
  final String cards;

  /// What to do with an attached photo; both chats can be sent one.
  final String photos;
  final String askPersona;
  final Map<String, String> skills;

  static TutorAssets? _cached;

  static Future<TutorAssets> load({AssetBundle? bundle}) async {
    if (bundle == null && _cached != null) return _cached!;
    final b = bundle ?? rootBundle;
    Future<String> read(String path) => b.loadString('assets/learn/$path');
    final assets = TutorAssets(
      tutorPersona: await read('prompts/tutor_persona.md'),
      tutorBase: await read('prompts/tutor_base.md'),
      choices: await read('prompts/choices.md'),
      cards: await read('prompts/cards.md'),
      photos: await read('prompts/photos.md'),
      askPersona: await read('prompts/ask_persona.md'),
      skills: {
        for (final name in skillNames) name: await read('skills/$name.md'),
      },
    );
    if (bundle == null) _cached = assets;
    return assets;
  }

  /// Everything that never changes between turns. It comes first so the
  /// provider's prefix cache keeps hitting.
  String get tutorStatic => [
        tutorPersona.trim(),
        tutorBase.trim(),
        choices.trim(),
        cards.trim(),
        photos.trim(),
        '# Skills\n\n'
            'Your teaching method, in three skills. They were written for a '
            'general harness; where one disagrees with "How this app works" '
            'above, the app wins.',
        for (final e in skills.entries) '<skill name="${e.key}">\n${e.value.trim()}\n</skill>',
      ].join('\n\n');
}

class TutorContext {
  const TutorContext({
    required this.course,
    required this.chapters,
    required this.preferences,
    required this.sessionKey,
    required this.today,
    this.chapter,
    this.sessionSummary,
  });

  final CourseRow course;
  final List<ChapterRow> chapters;
  final String preferences;
  final String sessionKey;
  final DateTime today;

  /// The chapter a lesson session teaches; null in the room.
  final ChapterRow? chapter;
  final String? sessionSummary;
}

// English whatever the app locale: the prompt itself is English.
String formatDay(DateTime d) => DateFormat('EEEE d MMMM y', 'en_US').format(d);

String isoDay(DateTime d) => DateFormat('yyyy-MM-dd', 'en_US').format(d);

String buildTutorPrompt(TutorAssets assets, TutorContext c) {
  final b = StringBuffer()
    ..writeln(assets.tutorStatic)
    ..writeln()
    ..writeln('# This course')
    ..writeln()
    ..writeln('- Course: “${c.course.title}”')
    ..writeln('- What the learner typed when creating it: '
        '${c.course.goal.isEmpty ? '(nothing)' : '“${c.course.goal}”'}');
  final ch = c.chapter;
  if (ch == null) {
    b.writeln('- Session: the course room (`$kRoomSessionKey`)');
  } else {
    b.writeln('- Session: the lesson for chapter `${ch.key}` — “${ch.title}” (${ch.status.name})');
  }
  b
    ..writeln('- Today: ${formatDay(c.today)}')
    ..writeln()
    ..writeln('## Chapters');
  if (c.chapters.isEmpty) {
    b.writeln('(none registered yet — probing and planning happen in the room)');
  } else {
    for (var i = 0; i < c.chapters.length; i++) {
      final x = c.chapters[i];
      final status = switch (x.status) {
        ChapterStatus.passed =>
          x.passedAt == null ? 'passed' : 'passed ${isoDay(x.passedAt!.toLocal())}',
        ChapterStatus.unlocked => 'unlocked ← current',
        ChapterStatus.locked => 'locked',
      };
      b.writeln('${i + 1}. `${x.key}` — ${x.title} — $status');
      if (x.summary.isNotEmpty) b.writeln('   ${x.summary}');
    }
  }
  b
    ..writeln()
    ..writeln('## state.md');
  if (c.course.stateMarkdown.trim().isEmpty) {
    b.writeln('(empty — nothing saved yet: this is the first session on this course)');
  } else {
    final saved = c.course.stateUpdatedAt;
    if (saved != null) b.writeln('Last saved ${isoDay(saved.toLocal())}.');
    b.writeln('<state_md>\n${c.course.stateMarkdown.trim()}\n</state_md>');
  }
  b
    ..writeln()
    ..writeln('## Teaching preferences (shared by every course)');
  b.writeln(c.preferences.trim().isEmpty
      ? '(none recorded yet)'
      : '<preferences>\n${c.preferences.trim()}\n</preferences>');
  if (ch != null) {
    b
      ..writeln()
      ..writeln("## This chapter's theory so far${ch.status == ChapterStatus.passed ? ' (frozen)' : ''}");
    b.writeln(ch.doc.trim().isEmpty
        ? '(nothing written yet)'
        : '<chapter_theory>\n${ch.doc.trim()}\n</chapter_theory>');
  }
  final summary = c.sessionSummary?.trim();
  if (summary != null && summary.isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Earlier in this session')
      ..writeln('The oldest messages of this session were summarized to save space:')
      ..writeln('<session_summary>\n$summary\n</session_summary>');
  }
  return b.toString().trimRight();
}

Future<String> tutorSystemPrompt({
  required LearnRepository repo,
  required TutorAssets assets,
  required int courseId,
  required int sessionId,
  required String sessionKey,
  DateTime? now,
}) async {
  final course = await repo.course(courseId);
  if (course == null) throw LearnRuleError('course $courseId no longer exists');
  final lessonKey = chapterKeyOf(sessionKey);
  return buildTutorPrompt(
    assets,
    TutorContext(
      course: course,
      chapters: await repo.chapters(courseId),
      preferences: await repo.preferences(),
      sessionKey: sessionKey,
      chapter: lessonKey == null ? null : await repo.chapter(courseId, lessonKey),
      sessionSummary: (await repo.sessionById(sessionId))?.summary,
      today: now ?? DateTime.now(),
    ),
  );
}

String buildAskPrompt(
  TutorAssets assets, {
  required List<CourseSummary> courses,
  required String preferences,
  required DateTime today,
}) {
  final b = StringBuffer()
    ..writeln(assets.askPersona.trim())
    ..writeln()
    ..writeln(assets.choices.trim())
    ..writeln()
    ..writeln(assets.cards.trim())
    ..writeln()
    ..writeln(assets.photos.trim())
    ..writeln()
    ..writeln('# Context')
    ..writeln()
    ..writeln('- Today: ${formatDay(today)}');
  if (courses.isEmpty) {
    b.writeln('- The learner has no course yet.');
  } else {
    b.writeln("- The learner's courses (for context; don't teach them here):");
    for (final s in courses) {
      final now = s.current == null ? '' : ', now on “${s.current!.title}”';
      b.writeln('  - “${s.course.title}” — ${s.passedCount}/${s.chapterCount} chapters$now');
    }
  }
  if (preferences.trim().isNotEmpty) {
    b
      ..writeln()
      ..writeln('## Teaching preferences')
      ..writeln('<preferences>\n${preferences.trim()}\n</preferences>');
  }
  return b.toString().trimRight();
}

String roomKickoffNote(CourseRow course) {
  final goal = course.goal.trim();
  return '(system note, not from the learner: the learner just opened the room '
      'of the course “${course.title}” for the first time'
      '${goal.isEmpty ? '' : ', having written “$goal” as its goal'}. Greet them '
      'in one line, then start Phase 1: concretize the goal, then probe, one '
      'question per message.)';
}

String lessonKickoffNote(ChapterRow chapter) {
  if (chapter.status == ChapterStatus.passed) {
    return '(system note, not from the learner: the learner opened the lesson '
        'of the passed chapter `${chapter.key}` — “${chapter.title}” — to revise '
        'it. Its theory is frozen. Offer a short retrieval check, or answer '
        'their questions.)';
  }
  return '(system note, not from the learner: the learner opened the lesson for '
      'chapter `${chapter.key}` — “${chapter.title}”. Teach it, one step at a '
      'time: course_write the step, explain it in chat, then check by '
      'application.)';
}

/// [ChatMessage.kind] of [kWrapUpNote].
const String kWrapUpKind = 'wrap_up';

const String kWrapUpNote =
    '(system note, not from the learner: the learner tapped "Wrap up". Run the '
    'session-end protocol now: save_state first, then a short summary of what '
    'was covered and what comes next.)';
