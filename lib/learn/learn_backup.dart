import 'dart:io';

import '../db/sqlite_open.dart';
import '../services/drive_sync.dart';
import 'db/learn_database.dart';
import 'db/learn_repository.dart';

/// Course snapshots on Drive, their own family beside the library's.
const kCoursesArtifact = DriveArtifact(
  prefix: 'iuna-learn-',
  local: SnapshotSpec(
    pendingFileName: kLearnPendingRestoreFileName,
    requiredTables: ['courses', 'chapters'],
    description: 'Iuna courses',
  ),
);

/// The tutor's database as something [DriveSync] can back up.
class CourseSnapshots implements DriveSnapshotSource {
  const CourseSnapshots(this.repo);

  final LearnRepository repo;

  @override
  DriveArtifact get artifact => kCoursesArtifact;

  @override
  String get label => 'courses';

  @override
  Future<DateTime?> lastContentChange() => repo.lastContentChange();

  @override
  Future<DateTime?> lastDriveBackup() => repo.getLastDriveBackup();

  @override
  Future<void> setLastDriveBackup(DateTime ts) => repo.setLastDriveBackup(ts);

  @override
  Future<void> writeSnapshot(File target) => repo.writeSnapshot(target);
}
