import 'dart:io';

import '../db/database.dart' show kPendingRestoreFileName;
import '../db/sqlite_open.dart';

/// The library's restore rules, shared by "Restore from file" and the
/// Drive restore.
const kLibrarySnapshot = SnapshotSpec(
  pendingFileName: kPendingRestoreFileName,
  requiredTables: ['cards', 'user_cards'],
  description: 'an Iuna library',
);

/// Result of a restore-staging attempt. The UI surfaces these reasons
/// directly so the user knows why a pick was rejected.
sealed class RestoreOutcome {
  const RestoreOutcome();
}

class RestoreStaged extends RestoreOutcome {
  const RestoreStaged();
}

class RestoreRejected extends RestoreOutcome {
  const RestoreRejected(this.reason);
  final String reason;
}

/// Validates [picked] and copies it to the side-car path that the next
/// database open swaps in. The live database is not touched, so
/// existing screens reading from it stay safe.
Future<RestoreOutcome> stagePendingRestore(File picked) async {
  final reason = await kLibrarySnapshot.validate(picked);
  if (reason != null) return RestoreRejected(reason);

  final pending = await kLibrarySnapshot.pendingFile();
  await pending.parent.create(recursive: true);
  await picked.copy(pending.path);
  return const RestoreStaged();
}
