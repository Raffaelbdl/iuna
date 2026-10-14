import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show protected;

import '../../db/meta_store.dart';
import '../../db/sqlite_open.dart';
import 'learn_database.dart';

class LearnMetaKeys {
  /// Bumped in the same transaction as every content write; the Drive
  /// backup compares it with [lastDriveBackupTs] to skip no-op uploads.
  static const updatedAt = 'updated_at';
  static const lastDriveBackupTs = 'last_drive_backup_ts';

  /// Cross-course teaching preferences, a markdown bullet list.
  static const preferences = 'preferences';
}

/// Session key of a course's room: probing, planning, cross-chapter
/// questions.
const String kRoomSessionKey = 'main';

const _chapterPrefix = 'ch-';

String chapterSessionKey(String chapterKey) => '$_chapterPrefix$chapterKey';

/// The chapter a lesson session teaches, or null for the room.
String? chapterKeyOf(String sessionKey) => sessionKey.startsWith(_chapterPrefix)
    ? sessionKey.substring(_chapterPrefix.length)
    : null;

/// A course rule the tutor tried to break. Enforced here rather than
/// asked of the model; the message goes back to it verbatim.
class LearnRuleError implements Exception {
  const LearnRuleError(this.message);
  final String message;

  @override
  String toString() => message;
}

class ChapterDraft {
  const ChapterDraft({required this.key, required this.title, this.summary = ''});
  final String key;
  final String title;
  final String summary;
}

class CourseSummary {
  const CourseSummary({
    required this.course,
    required this.chapterCount,
    required this.passedCount,
    required this.current,
  });

  final CourseRow course;
  final int chapterCount;
  final int passedCount;

  /// The unlocked chapter, or null before planning / after the last pass.
  final ChapterRow? current;
}

class LearnRepository with MetaTimestamps {
  LearnRepository(this.db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final LearnDatabase db;
  final DateTime Function() _clock;
  final _changes = StreamController<int>.broadcast();

  /// Ids of courses whose chapters, theory or state just changed.
  /// Screens showing a course reload on it — the tutor writes mid-turn.
  Stream<int> get changes => _changes.stream;

  DateTime get _now => _clock();

  Future<void> dispose() => _changes.close();

  // ---------- meta ----------

  Future<String?> _meta(String key) async {
    final row = await (db.select(db.learnMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) async {
    await db.into(db.learnMeta).insertOnConflictUpdate(
          LearnMetaCompanion.insert(key: key, value: value),
        );
  }

  @override
  @protected
  Future<String?> readMeta(String key) => _meta(key);

  @override
  @protected
  Future<void> writeMeta(String key, String value) => _setMeta(key, value);

  Future<void> _touch() => writeTimestamp(LearnMetaKeys.updatedAt, _now);

  Future<DateTime?> lastContentChange() => readTimestamp(LearnMetaKeys.updatedAt);

  Future<DateTime?> getLastDriveBackup() =>
      readTimestamp(LearnMetaKeys.lastDriveBackupTs);

  Future<void> setLastDriveBackup(DateTime ts) =>
      writeTimestamp(LearnMetaKeys.lastDriveBackupTs, ts);

  /// A consistent copy of the whole database at [target], even while the
  /// tutor is writing.
  Future<void> writeSnapshot(File target) => vacuumInto(db, target);

  // ---------- courses ----------

  Future<CourseRow> createCourse({
    required String title,
    String goal = '',
  }) async {
    final name = title.trim();
    if (name.isEmpty) throw const LearnRuleError('a course needs a title');
    return db.transaction(() async {
      final now = _now;
      final id = await db.into(db.courses).insert(CoursesCompanion.insert(
            title: name,
            goal: Value(goal.trim()),
            createdAt: now,
            updatedAt: now,
          ));
      await _touch();
      return (await course(id))!;
    });
  }

  Future<CourseRow?> course(int id) =>
      (db.select(db.courses)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<List<CourseRow>> courses() => (db.select(db.courses)
        ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
      .get();

  /// Three queries whatever the number of courses: the hub reloads this
  /// on every tutor write, and only the unlocked chapters' rows are read
  /// whole (with their theory).
  Future<List<CourseSummary>> courseSummaries() async {
    final ch = db.chapters;
    final live = ch.dropped.equals(false);
    final total = ch.id.count();
    final passed = ch.id.count(filter: ch.status.equalsValue(ChapterStatus.passed));
    final countRows = await (db.selectOnly(ch)
          ..addColumns([ch.courseId, total, passed])
          ..where(live)
          ..groupBy([ch.courseId]))
        .get();
    final counts = {
      for (final r in countRows)
        r.read(ch.courseId)!: (total: r.read(total)!, passed: r.read(passed)!),
    };
    final unlocked = await (db.select(ch)
          ..where((c) => live & c.status.equalsValue(ChapterStatus.unlocked))
          ..orderBy([(c) => OrderingTerm.asc(c.ordinal)]))
        .get();
    final current = <int, ChapterRow>{};
    for (final c in unlocked) {
      current.putIfAbsent(c.courseId, () => c);
    }
    return [
      for (final c in await courses())
        CourseSummary(
          course: c,
          chapterCount: counts[c.id]?.total ?? 0,
          passedCount: counts[c.id]?.passed ?? 0,
          current: current[c.id],
        ),
    ];
  }

  Future<void> renameCourse(int id, String title) async {
    final name = title.trim();
    if (name.isEmpty) return;
    await db.transaction(() async {
      await (db.update(db.courses)..where((c) => c.id.equals(id)))
          .write(CoursesCompanion(title: Value(name)));
      await _touch();
    });
    _changes.add(id);
  }

  Future<void> deleteCourse(int id) async {
    await db.transaction(() async {
      await (db.delete(db.courses)..where((c) => c.id.equals(id))).go();
      await _touch();
    });
    _changes.add(id);
  }

  /// Replaces the course's state.md whole — the tutor rewrites it at
  /// session end, it never patches it.
  Future<void> saveState(int courseId, String markdown) async {
    await db.transaction(() async {
      await _requireCourse(courseId);
      final now = _now;
      await (db.update(db.courses)..where((c) => c.id.equals(courseId))).write(
        CoursesCompanion(
          stateMarkdown: Value(markdown.trim()),
          stateUpdatedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _touch();
    });
    _changes.add(courseId);
  }

  Future<CourseRow> _requireCourse(int courseId) async {
    final c = await course(courseId);
    if (c == null) throw LearnRuleError('course $courseId no longer exists');
    return c;
  }

  Future<void> _bumpCourse(int courseId) async {
    await (db.update(db.courses)..where((c) => c.id.equals(courseId)))
        .write(CoursesCompanion(updatedAt: Value(_now)));
  }

  // ---------- chapters ----------

  /// The current plan, in teaching order. Dropped chapters are hidden.
  Future<List<ChapterRow>> chapters(int courseId) => (db.select(db.chapters)
        ..where((c) => c.courseId.equals(courseId) & c.dropped.equals(false))
        ..orderBy([(c) => OrderingTerm.asc(c.ordinal)]))
      .get();

  Future<ChapterRow?> chapter(int courseId, String key) =>
      (db.select(db.chapters)
            ..where((c) =>
                c.courseId.equals(courseId) &
                c.key.equals(key) &
                c.dropped.equals(false)))
          .getSingleOrNull();

  Future<ChapterRow> _requireChapter(int courseId, String key) async {
    final ch = await chapter(courseId, key);
    if (ch != null) return ch;
    final known = (await chapters(courseId)).map((c) => c.key).join(', ');
    throw LearnRuleError(
      "no chapter '$key' in the course; known chapters: "
      "${known.isEmpty ? '(none yet — register them with course_plan)' : known}",
    );
  }

  /// Registers the tutor's chapter list. Statuses are derived, never
  /// taken from the model: passed stays passed (even across a drop and
  /// re-add), the first non-passed chapter unlocks, the rest lock.
  Future<List<ChapterRow>> applyPlan(
    int courseId,
    List<ChapterDraft> drafts,
  ) async {
    await db.transaction(() async {
      await _requireCourse(courseId);
      final all = await (db.select(db.chapters)
            ..where((c) => c.courseId.equals(courseId)))
          .get();
      final existing = {for (final c in all) c.key: c};
      final kept = <String>{};
      for (var i = 0; i < drafts.length; i++) {
        final d = drafts[i];
        kept.add(d.key);
        final old = existing[d.key];
        if (old == null) {
          await db.into(db.chapters).insert(ChaptersCompanion.insert(
                courseId: courseId,
                key: d.key,
                ordinal: i,
                title: d.title,
                summary: Value(d.summary),
                status: ChapterStatus.locked,
              ));
        } else {
          await (db.update(db.chapters)..where((c) => c.id.equals(old.id)))
              .write(ChaptersCompanion(
            ordinal: Value(i),
            title: Value(d.title),
            summary: Value(d.summary),
            dropped: const Value(false),
          ));
        }
      }
      for (final old in all) {
        if (!kept.contains(old.key) && !old.dropped) {
          await (db.update(db.chapters)..where((c) => c.id.equals(old.id)))
              .write(const ChaptersCompanion(dropped: Value(true)));
        }
      }
      await _rederive(courseId);
      await _bumpCourse(courseId);
      await _touch();
    });
    _changes.add(courseId);
    return chapters(courseId);
  }

  Future<void> _rederive(int courseId) async {
    var unlockedGiven = false;
    for (final c in await chapters(courseId)) {
      final ChapterStatus next;
      if (c.status == ChapterStatus.passed) {
        next = ChapterStatus.passed;
      } else if (!unlockedGiven) {
        next = ChapterStatus.unlocked;
        unlockedGiven = true;
      } else {
        next = ChapterStatus.locked;
      }
      if (next != c.status) {
        await (db.update(db.chapters)..where((r) => r.id.equals(c.id)))
            .write(ChaptersCompanion(status: Value(next)));
      }
    }
  }

  /// Appends one theory section. Append-only so the learner revises
  /// from the text they learned from, and refused once passed.
  Future<ChapterRow> appendChapterDoc(
    int courseId,
    String key,
    String markdown,
  ) async {
    final body = markdown.trim();
    if (body.isEmpty) {
      throw const LearnRuleError("'markdown' is empty; write the section's theory");
    }
    final updated = await db.transaction(() async {
      final ch = await _requireChapter(courseId, key);
      if (ch.status == ChapterStatus.locked) {
        throw LearnRuleError(
          "chapter '$key' is locked — the learner has not reached it. "
          'Teach the unlocked chapter first.',
        );
      }
      if (ch.status == ChapterStatus.passed) {
        throw LearnRuleError(
          "chapter '$key' is passed, so its theory is frozen. Explain the "
          'point in chat, or note it in state.md.',
        );
      }
      final doc = ch.doc.trim().isEmpty
          ? '$body\n'
          : '${ch.doc.trimRight()}\n\n$body\n';
      await (db.update(db.chapters)..where((c) => c.id.equals(ch.id)))
          .write(ChaptersCompanion(doc: Value(doc)));
      await _bumpCourse(courseId);
      await _touch();
      return ch.copyWith(doc: doc);
    });
    _changes.add(courseId);
    return updated;
  }

  /// Passes the unlocked chapter, freezing its theory and unlocking the
  /// next. Returns the newly unlocked chapter, or null when the course
  /// is complete.
  Future<ChapterRow?> passChapter(int courseId, String key) async {
    final next = await db.transaction(() async {
      final ch = await _requireChapter(courseId, key);
      if (ch.status != ChapterStatus.unlocked) {
        throw LearnRuleError(
          "chapter '$key' is ${ch.status.name}, not unlocked; only the "
          'chapter currently being taught can be passed',
        );
      }
      await (db.update(db.chapters)..where((c) => c.id.equals(ch.id))).write(
        ChaptersCompanion(
          status: const Value(ChapterStatus.passed),
          passedAt: Value(_now),
        ),
      );
      await _rederive(courseId);
      await _bumpCourse(courseId);
      await _touch();
      return (await chapters(courseId))
          .where((c) => c.status == ChapterStatus.unlocked)
          .firstOrNull;
    });
    _changes.add(courseId);
    return next;
  }

  // ---------- preferences ----------

  Future<String> preferences() async =>
      await _meta(LearnMetaKeys.preferences) ?? '';

  static final _bullet = RegExp(r'^\s*[-*•]\s*');

  /// Appends one preference line; returns false when it was already
  /// there (case-insensitive).
  Future<bool> addPreference(String text) async {
    final fact = text.trim().replaceFirst(_bullet, '').trim();
    if (fact.isEmpty) throw const LearnRuleError('the preference is empty');
    final current = await preferences();
    final seen = current
        .split('\n')
        .map((l) => l.replaceFirst(_bullet, '').trim().toLowerCase())
        .toSet();
    if (seen.contains(fact.toLowerCase())) return false;
    final next =
        current.trim().isEmpty ? '- $fact\n' : '${current.trimRight()}\n- $fact\n';
    await db.transaction(() async {
      await _setMeta(LearnMetaKeys.preferences, next);
      await _touch();
    });
    return true;
  }

  // ---------- sessions & messages ----------

  Future<SessionRow> openSession(int courseId, String key) async {
    final existing = await (db.select(db.chatSessions)
          ..where((s) => s.courseId.equals(courseId) & s.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final now = _now;
    final id = await db.into(db.chatSessions).insert(ChatSessionsCompanion.insert(
          courseId: courseId,
          key: key,
          createdAt: now,
          updatedAt: now,
        ));
    return (await sessionById(id))!;
  }

  Future<SessionRow?> sessionById(int id) =>
      (db.select(db.chatSessions)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  /// Every message, archived ones included — the learner still scrolls
  /// back through them; only the model sees the summary instead.
  Future<List<MessageRow>> messages(int sessionId) => (db.select(db.messages)
        ..where((m) => m.sessionId.equals(sessionId))
        ..orderBy([(m) => OrderingTerm.asc(m.id)]))
      .get();

  Future<MessageRow> addMessage(
    int sessionId, {
    required MessageRole role,
    String content = '',
    String? toolCalls,
    String? toolCallId,
    String? toolName,
    String? kind,
    String? attachments,
  }) {
    return db.transaction(() async {
      final now = _now;
      final id = await db.into(db.messages).insert(MessagesCompanion.insert(
            sessionId: sessionId,
            role: role,
            content: Value(content),
            toolCalls: Value(toolCalls),
            toolCallId: Value(toolCallId),
            toolName: Value(toolName),
            kind: Value(kind),
            attachments: Value(attachments),
            createdAt: now,
          ));
      final session = await sessionById(sessionId);
      await (db.update(db.chatSessions)..where((s) => s.id.equals(sessionId)))
          .write(ChatSessionsCompanion(updatedAt: Value(now)));
      if (session != null) await _bumpCourse(session.courseId);
      await _touch();
      return (await (db.select(db.messages)..where((m) => m.id.equals(id)))
          .getSingle());
    });
  }

  /// Folds every message up to [throughMessageId] into [summary].
  Future<void> compactSession(
    int sessionId, {
    required int throughMessageId,
    required String summary,
  }) async {
    await db.transaction(() async {
      await (db.update(db.messages)
            ..where((m) =>
                m.sessionId.equals(sessionId) &
                m.id.isSmallerOrEqualValue(throughMessageId)))
          .write(const MessagesCompanion(archived: Value(true)));
      await (db.update(db.chatSessions)..where((s) => s.id.equals(sessionId)))
          .write(ChatSessionsCompanion(summary: Value(summary)));
      await _touch();
    });
  }

  // ---------- usage ----------

  Future<void> recordUsage({
    int? courseId,
    required String kind,
    required String model,
    int promptTokens = 0,
    int completionTokens = 0,
    double? cost,
  }) async {
    await db.into(db.usageLog).insert(UsageLogCompanion.insert(
          courseId: Value(courseId),
          kind: kind,
          model: model,
          promptTokens: Value(promptTokens),
          completionTokens: Value(completionTokens),
          cost: Value(cost),
          at: _now,
        ));
  }

  /// USD spent, for one course or (null) everything on this device.
  Future<double> totalCost({int? courseId}) async {
    final sum = db.usageLog.cost.sum();
    final q = db.selectOnly(db.usageLog)..addColumns([sum]);
    if (courseId != null) q.where(db.usageLog.courseId.equals(courseId));
    return await q.map((r) => r.read(sum)).getSingle() ?? 0;
  }
}
