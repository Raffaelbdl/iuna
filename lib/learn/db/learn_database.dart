import 'package:drift/drift.dart';

import '../../db/sqlite_open.dart';

part 'learn_database.g.dart';

/// Kept apart from the deck database on purpose: courses change far
/// less often than reviews, so they get their own Drive snapshot family
/// (and their own restore), and the deck schema never has to know the
/// tutor exists.
const String kLearnDbFileName = 'learn.sqlite';

/// Same pending-then-apply restore dance as `kPendingRestoreFileName`.
const String kLearnPendingRestoreFileName = 'learn.sqlite.pending';

/// The course is linear: passed chapters stay passed, the first
/// non-passed one is unlocked, everything after it is locked. Stored as
/// text so a snapshot stays readable in any sqlite browser.
enum ChapterStatus { locked, unlocked, passed }

/// `note` is a message from the app itself (the learner opened a
/// lesson, tapped "Wrap up"). It reaches the model as a user-role
/// message but is never shown as something the learner said.
enum MessageRole { user, assistant, tool, note }

@DataClassName('CourseRow')
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// What the learner typed when creating the course. The tutor turns
  /// it into a concrete goal during the probe; that goal lives in
  /// [stateMarkdown], not here.
  TextColumn get goal => text().withDefault(const Constant(''))();

  /// The tutor's `state.md`: its entire memory of this learner for this
  /// course. Rewritten whole by the `save_state` tool.
  TextColumn get stateMarkdown => text().withDefault(const Constant(''))();
  DateTimeColumn get stateUpdatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Last activity of any kind, for ordering the course list.
  DateTimeColumn get updatedAt => dateTime()();
}

@DataClassName('ChapterRow')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();

  /// The tutor-chosen slug (`te-form-requests`); the lesson session is
  /// named `ch-<key>` after it.
  TextColumn get key => text()();
  IntColumn get ordinal => integer()();
  TextColumn get title => text()();
  TextColumn get summary => text().withDefault(const Constant(''))();
  TextColumn get status => textEnum<ChapterStatus>()();
  DateTimeColumn get passedAt => dateTime().nullable()();

  /// Theory document, append-only while unlocked, frozen once passed.
  TextColumn get doc => text().withDefault(const Constant(''))();

  /// Left out of the latest plan. The row survives so a re-plan that
  /// brings the key back finds its theory, and a passed chapter can
  /// never be un-passed by being dropped and re-added.
  BoolColumn get dropped => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, key},
      ];
}

@DataClassName('SessionRow')
class ChatSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId =>
      integer().references(Courses, #id, onDelete: KeyAction.cascade)();

  /// `main` for the course room, `ch-<chapter key>` for a lesson.
  TextColumn get key => text()();

  /// Summary of the messages compaction archived. Sent to the model in
  /// place of them; the archived rows stay visible to the learner.
  TextColumn get summary => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {courseId, key},
      ];
}

@DataClassName('MessageRow')
class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(ChatSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => textEnum<MessageRole>()();
  TextColumn get content => text().withDefault(const Constant(''))();

  /// JSON array of `{id, name, arguments}` on an assistant turn that
  /// called tools.
  TextColumn get toolCalls => text().nullable()();

  /// On a `tool` row: which call this answers, and the tool's name.
  TextColumn get toolCallId => text().nullable()();
  TextColumn get toolName => text().nullable()();

  /// What an app note is for (`kickoff`, `wrap_up`), so the view can
  /// caption it without matching its text.
  TextColumn get kind => text().nullable()();

  /// JSON array of `{mime, data}` — photos the learner attached, base64
  /// in the row. They ride along with a Drive snapshot and a course
  /// deletion takes them with it, which no side file would.
  TextColumn get attachments => text().nullable()();

  /// Folded into [ChatSessions.summary] by compaction.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('LearnMetaRow')
class LearnMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One row per model call, so the learner can see what the tutor costs.
/// Survives course deletion (course id nulled) so the lifetime total
/// stays honest.
@DataClassName('UsageRow')
class UsageLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get courseId => integer()
      .nullable()
      .references(Courses, #id, onDelete: KeyAction.setNull)();

  /// `chat`, `ask`, `compact` or `dictation`.
  TextColumn get kind => text()();
  TextColumn get model => text()();
  IntColumn get promptTokens => integer().withDefault(const Constant(0))();
  IntColumn get completionTokens =>
      integer().withDefault(const Constant(0))();

  /// USD as reported by OpenRouter; null when the provider didn't say.
  RealColumn get cost => real().nullable()();
  DateTimeColumn get at => dateTime()();
}

@DriftDatabase(
  tables: [Courses, Chapters, ChatSessions, Messages, LearnMeta, UsageLog],
)
class LearnDatabase extends _$LearnDatabase {
  LearnDatabase()
      : super(openDocumentsDatabase(
          kLearnDbFileName,
          pendingFileName: kLearnPendingRestoreFileName,
        ));

  LearnDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.addColumn(messages, messages.kind);
          if (from < 3) await m.addColumn(messages, messages.attachments);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
