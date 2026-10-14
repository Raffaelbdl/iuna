import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/agent/tutor_prompt.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LearnDatabase db;
  late LearnRepository repo;

  setUp(() {
    db = LearnDatabase.forTesting(NativeDatabase.memory());
    repo = LearnRepository(db);
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  test('the tutor prompt carries persona, harness, all three skills, then the course',
      () async {
    final assets = await TutorAssets.load();
    final course = await repo.createCourse(title: 'Keigo', goal: 'talk to clients');
    await repo.applyPlan(course.id, const [
      ChapterDraft(key: 'teineigo', title: 'Polite speech', summary: 'です/ます everywhere'),
      ChapterDraft(key: 'sonkeigo', title: 'Respectful speech'),
    ]);
    await repo.appendChapterDoc(course.id, 'teineigo', '## です and ます');
    await repo.saveState(course.id, '## Map\n- polite forms: solid');
    await repo.addPreference('prefers example-first');
    final lesson = await repo.openSession(course.id, chapterSessionKey('teineigo'));

    final prompt = await tutorSystemPrompt(
      repo: repo,
      assets: assets,
      courseId: course.id,
      sessionId: lesson.id,
      sessionKey: chapterSessionKey('teineigo'),
      now: DateTime(2026, 9, 10),
    );

    expect(prompt, startsWith('You are Kuma-sensei'));
    for (final skill in TutorAssets.skillNames) {
      expect(prompt, contains('<skill name="$skill">'));
    }
    expect(prompt.indexOf('# How this app works'), lessThan(prompt.indexOf('# This course')),
        reason: 'static text first, so the provider prefix cache keeps hitting');
    expect(prompt, contains('- Today: Thursday 10 September 2026'));
    expect(prompt, contains('1. `teineigo` — Polite speech — unlocked ← current'));
    expect(prompt, contains('2. `sonkeigo` — Respectful speech — locked'));
    expect(prompt, contains('<state_md>\n## Map\n- polite forms: solid\n</state_md>'));
    expect(prompt, contains('- prefers example-first'));
    expect(prompt, contains('<chapter_theory>\n## です and ます\n</chapter_theory>'));
    expect(prompt, contains('lesson for chapter `teineigo`'));
    expect(prompt, contains('```choices'), reason: 'the multiple-choice contract');
    expect(prompt, contains("# The learner's cards"), reason: 'when to bookmark');

    // The adapted skills must not send the model after guu-only tools.
    for (final gone in ['assign_homework', 'review_homework', 'ws_read', 'ws_write', 'homework.json', 'KaTeX']) {
      expect(prompt, isNot(contains(gone)), reason: gone);
    }
  });

  test('the ask prompt lists courses and preferences, and promises no course tools',
      () async {
    final assets = await TutorAssets.load();
    final c = await repo.createCourse(title: 'JLPT N1');
    await repo.applyPlan(c.id, const [ChapterDraft(key: 'a', title: 'Formal grammar')]);
    final prompt = buildAskPrompt(
      assets,
      courses: await repo.courseSummaries(),
      preferences: '- wants furigana',
      today: DateTime(2026, 9, 10),
    );
    expect(prompt, contains('quick-question chat'));
    expect(prompt, contains('“JLPT N1” — 0/1 chapters, now on “Formal grammar”'));
    expect(prompt, contains('- wants furigana'));
    expect(prompt, contains('```choices'), reason: 'the multiple-choice contract');
    expect(prompt, isNot(contains('course_plan')));
    expect(prompt, contains("# The learner's cards"), reason: 'Ask can bookmark too');
  });
}
