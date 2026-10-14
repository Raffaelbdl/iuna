import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';

void main() {
  late LearnDatabase db;
  late LearnRepository repo;
  var clock = DateTime.utc(2026, 9, 10, 8);

  setUp(() {
    clock = DateTime.utc(2026, 9, 10, 8);
    db = LearnDatabase.forTesting(NativeDatabase.memory());
    repo = LearnRepository(db, clock: () => clock);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  List<ChapterDraft> drafts(List<String> keys) => [
        for (final k in keys) ChapterDraft(key: k, title: 'Title $k'),
      ];

  Future<Map<String, ChapterStatus>> statuses(int courseId) async => {
        for (final c in await repo.chapters(courseId)) c.key: c.status,
      };

  test('a plan unlocks the first chapter and locks the rest', () async {
    final course = await repo.createCourse(title: 'JLPT N1');
    await repo.applyPlan(course.id, drafts(['a', 'b', 'c']));
    expect(await statuses(course.id), {
      'a': ChapterStatus.unlocked,
      'b': ChapterStatus.locked,
      'c': ChapterStatus.locked,
    });
  });

  test('passing advances the unlock; the last pass completes the course',
      () async {
    final course = await repo.createCourse(title: 'Keigo');
    await repo.applyPlan(course.id, drafts(['a', 'b']));

    final next = await repo.passChapter(course.id, 'a');
    expect(next?.key, 'b');
    expect(await statuses(course.id),
        {'a': ChapterStatus.passed, 'b': ChapterStatus.unlocked});

    expect(await repo.passChapter(course.id, 'b'), isNull);
  });

  test('only the unlocked chapter can be passed', () async {
    final course = await repo.createCourse(title: 'Keigo');
    await repo.applyPlan(course.id, drafts(['a', 'b']));
    await expectLater(
      repo.passChapter(course.id, 'b'),
      throwsA(isA<LearnRuleError>()
          .having((e) => e.message, 'message', contains('locked'))),
    );
    await expectLater(
      repo.passChapter(course.id, 'zzz'),
      throwsA(isA<LearnRuleError>()
          .having((e) => e.message, 'message', contains('known chapters: a, b'))),
    );
  });

  test('theory is append-only, refused when locked, frozen once passed',
      () async {
    final course = await repo.createCourse(title: 'Grammar');
    await repo.applyPlan(course.id, drafts(['a', 'b']));

    await repo.appendChapterDoc(course.id, 'a', 'First idea.');
    final ch = await repo.appendChapterDoc(course.id, 'a', '  Second idea. ');
    expect(ch.doc, 'First idea.\n\nSecond idea.\n');

    await expectLater(repo.appendChapterDoc(course.id, 'b', 'too early'),
        throwsA(isA<LearnRuleError>()));

    await repo.passChapter(course.id, 'a');
    await expectLater(repo.appendChapterDoc(course.id, 'a', 'rewrite'),
        throwsA(isA<LearnRuleError>()
            .having((e) => e.message, 'message', contains('frozen'))));
    expect((await repo.chapter(course.id, 'a'))!.doc,
        'First idea.\n\nSecond idea.\n');
  });

  test('a refused write leaves nothing behind', () async {
    final course = await repo.createCourse(title: 'Grammar');
    await repo.applyPlan(course.id, drafts(['a', 'b']));
    final before = await repo.lastContentChange();
    clock = clock.add(const Duration(minutes: 5));
    await expectLater(repo.appendChapterDoc(course.id, 'b', 'x'),
        throwsA(isA<LearnRuleError>()));
    expect(await repo.lastContentChange(), before);
    expect((await repo.chapter(course.id, 'b'))!.doc, isEmpty);
  });

  test('a re-plan keeps passed chapters passed, even dropped and re-added',
      () async {
    final course = await repo.createCourse(title: 'Business Japanese');
    await repo.applyPlan(course.id, drafts(['a', 'b', 'c']));
    await repo.appendChapterDoc(course.id, 'a', 'Theory of a.');
    await repo.passChapter(course.id, 'a');

    // Insert a new chapter first and drop `a`: `new` becomes current.
    await repo.applyPlan(course.id, drafts(['new', 'b', 'c']));
    expect(await statuses(course.id), {
      'new': ChapterStatus.unlocked,
      'b': ChapterStatus.locked,
      'c': ChapterStatus.locked,
    });

    // Bringing `a` back finds it passed, theory intact.
    await repo.applyPlan(course.id, drafts(['a', 'new', 'b']));
    expect(await statuses(course.id), {
      'a': ChapterStatus.passed,
      'new': ChapterStatus.unlocked,
      'b': ChapterStatus.locked,
    });
    expect((await repo.chapter(course.id, 'a'))!.doc, 'Theory of a.\n');
    expect(await repo.chapter(course.id, 'c'), isNull,
        reason: 'dropped chapters are hidden from the plan');
  });

  test('every content write bumps updated_at; usage does not', () async {
    expect(await repo.lastContentChange(), isNull);
    final course = await repo.createCourse(title: 'N1');
    expect(await repo.lastContentChange(), clock.toLocal());

    clock = clock.add(const Duration(hours: 1));
    await repo.recordUsage(courseId: course.id, kind: 'chat', model: 'm');
    expect(await repo.lastContentChange(),
        clock.subtract(const Duration(hours: 1)).toLocal());

    await repo.saveState(course.id, '# state');
    expect(await repo.lastContentChange(), clock.toLocal());
    expect((await repo.course(course.id))!.stateMarkdown, '# state');
  });

  test('preferences dedupe case-insensitively', () async {
    expect(await repo.addPreference('Prefers example-first'), isTrue);
    expect(await repo.addPreference('- prefers EXAMPLE-first'), isFalse);
    expect(await repo.addPreference('Wants furigana on N2+ kanji'), isTrue);
    expect(await repo.preferences(),
        '- Prefers example-first\n- Wants furigana on N2+ kanji\n');
  });

  test('sessions are per course and key; compaction archives up to an id',
      () async {
    final course = await repo.createCourse(title: 'N1');
    final room = await repo.openSession(course.id, kRoomSessionKey);
    expect((await repo.openSession(course.id, kRoomSessionKey)).id, room.id);
    final lesson = await repo.openSession(course.id, chapterSessionKey('a'));
    expect(lesson.id, isNot(room.id));

    final m1 = await repo.addMessage(room.id,
        role: MessageRole.user, content: 'hello');
    await repo.addMessage(room.id, role: MessageRole.assistant, content: 'hi');
    await repo.compactSession(room.id,
        throughMessageId: m1.id, summary: 'greeted');

    final msgs = await repo.messages(room.id);
    expect(msgs.map((m) => m.archived), [true, false]);
    expect((await repo.sessionById(room.id))!.summary, 'greeted');
  });

  test('cost totals per course and overall survive course deletion',
      () async {
    final a = await repo.createCourse(title: 'A');
    final b = await repo.createCourse(title: 'B');
    await repo.recordUsage(courseId: a.id, kind: 'chat', model: 'm', cost: 0.01);
    await repo.recordUsage(courseId: b.id, kind: 'chat', model: 'm', cost: 0.02);
    await repo.recordUsage(kind: 'ask', model: 'm', cost: 0.005);

    expect(await repo.totalCost(courseId: a.id), closeTo(0.01, 1e-9));
    expect(await repo.totalCost(), closeTo(0.035, 1e-9));

    await repo.deleteCourse(a.id);
    expect(await repo.courses(), hasLength(1));
    expect(await repo.totalCost(), closeTo(0.035, 1e-9));
  });

  test('course summaries report progress and the current chapter', () async {
    final c = await repo.createCourse(title: 'N1', goal: 'pass N1 in December');
    await repo.applyPlan(c.id, drafts(['a', 'b', 'c']));
    await repo.passChapter(c.id, 'a');
    final s = (await repo.courseSummaries()).single;
    expect(s.chapterCount, 3);
    expect(s.passedCount, 1);
    expect(s.current?.key, 'b');
    expect(s.course.goal, 'pass N1 in December');
  });
}
