import 'dart:async';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/repository.dart';
import '../db/sqlite_open.dart';
import 'db_restore.dart';
import 'drive_auth.dart';

sealed class BackupResult {
  const BackupResult();
}

class BackupSucceeded extends BackupResult {
  const BackupSucceeded(this.snapshot);
  final DriveSnapshot snapshot;
}

class BackupNotSignedIn extends BackupResult {
  const BackupNotSignedIn();
}

class BackupQuotaExceeded extends BackupResult {
  const BackupQuotaExceeded();
}

class BackupFailed extends BackupResult {
  const BackupFailed(this.message);
  final String message;
}

/// Nothing uploaded: the source hasn't changed since its last snapshot.
/// Only [DriveSync.backupSource] returns it.
class BackupUnchanged extends BackupResult {
  const BackupUnchanged();
}

sealed class DriveRestoreResult {
  const DriveRestoreResult();
}

class DriveRestoreStaged extends DriveRestoreResult {
  const DriveRestoreStaged();
}

class DriveRestoreNotSignedIn extends DriveRestoreResult {
  const DriveRestoreNotSignedIn();
}

class DriveRestoreFailed extends DriveRestoreResult {
  const DriveRestoreFailed(this.message);
  final String message;
}

class DriveSnapshot {
  const DriveSnapshot({
    required this.id,
    required this.name,
    this.size,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final int? size;
  final DateTime? modifiedTime;
}

/// A family of snapshots in the shared `appDataFolder`. Names are
/// `<prefix>yyyyMMdd-HHmmss.sqlite`, and a family owns only names of
/// exactly that shape, so listing, retention and restore never mix two
/// families up (without it, seven course uploads would evict every
/// library snapshot).
class DriveArtifact {
  const DriveArtifact({required this.prefix, required this.local});

  static const library = DriveArtifact(prefix: 'iuna-', local: kLibrarySnapshot);

  final String prefix;

  /// Where a restore stages the download, and what it must hold.
  final SnapshotSpec local;

  static final _stamp = RegExp(r'^\d{8}-\d{6}\.sqlite$');

  bool owns(String? name) =>
      name != null &&
      name.startsWith(prefix) &&
      _stamp.hasMatch(name.substring(prefix.length));

  String snapshotName(DateTime ts) =>
      '$prefix${DateFormat('yyyyMMdd-HHmmss').format(ts.toLocal())}.sqlite';
}

/// A database [DriveSync] can back up: the library itself, or one that
/// rides along with it and goes up only when it changed.
abstract interface class DriveSnapshotSource {
  DriveArtifact get artifact;

  /// How the UI names it, e.g. "courses".
  String get label;

  Future<DateTime?> lastContentChange();
  Future<DateTime?> lastDriveBackup();
  Future<void> setLastDriveBackup(DateTime ts);

  /// Writes a consistent copy of the database to [target], which does
  /// not exist yet.
  Future<void> writeSnapshot(File target);
}

/// One snack line for a library backup and whatever rode [alongside];
/// null means stay quiet.
String? backupMessage(
  ({BackupResult library, BackupResult? alongside}) result, {
  DriveSnapshotSource? alongside,
  bool quietWhenSignedOut = false,
}) {
  final label = alongside?.label ?? 'the rest';
  switch (result.library) {
    case BackupNotSignedIn():
      return quietWhenSignedOut ? null : 'Not signed in';
    case BackupQuotaExceeded():
      return 'Your Drive is full';
    case BackupFailed(:final message):
      return 'Backup failed: $message';
    case BackupUnchanged():
      return null;
    case BackupSucceeded():
      return switch (result.alongside) {
        BackupSucceeded() => 'Backed up library and $label · just now',
        BackupFailed(:final message) => 'Library backed up; $label failed: $message',
        BackupQuotaExceeded() => 'Library backed up; no Drive space left for $label',
        _ => 'Backed up · just now',
      };
  }
}

/// Orchestrates `appDataFolder` operations: timestamped backup uploads,
/// snapshot listing, restore-into-pending-file, and N-newest retention
/// pruning. Wraps [DriveAuth] for the authenticated client and
/// [IunaRepository] for the library snapshot + last-backup timestamp.
class DriveSync {
  /// Production callers don't pass [apiProvider]; it defaults to
  /// [DriveAuth.instance.client]. Tests inject a fake `DriveApi` built
  /// over a mocked `http.Client`.
  DriveSync(
    this.repo, {
    Future<drive.DriveApi?> Function()? apiProvider,
  }) : _apiProvider = apiProvider ?? DriveAuth.instance.client;

  final IunaRepository repo;
  final Future<drive.DriveApi?> Function() _apiProvider;

  /// Number of newest snapshots kept on Drive, per family, after a
  /// successful upload; older files are deleted. `appDataFolder` quota
  /// counts against the user's Drive, so we don't hoard.
  static const int retentionCount = 7;

  /// Pull-to-refresh and Settings can both start a backup; the second
  /// joins the first rather than racing it.
  static Future<({BackupResult library, BackupResult? alongside})>?
      _backupInFlight;

  /// Uploads the library unconditionally.
  Future<BackupResult> backup({DateTime? now}) =>
      backupSource(_LibrarySnapshots(repo), now: now, force: true);

  /// Uploads [source] only when it changed since its last snapshot;
  /// [force] skips that check.
  Future<BackupResult> backupSource(
    DriveSnapshotSource source, {
    DateTime? now,
    bool force = false,
  }) async {
    if (!force && !await _changed(source)) return const BackupUnchanged();
    final api = await _apiProvider();
    if (api == null) return const BackupNotSignedIn();
    final result = await _uploadSnapshot(api, source, now);
    if (result is BackupSucceeded) await _prune(api, [source.artifact]);
    return result;
  }

  /// The library every time, and [alongside] when it changed.
  Future<({BackupResult library, BackupResult? alongside})> backupAll({
    DriveSnapshotSource? alongside,
    DateTime? now,
  }) {
    return _backupInFlight ??= _backupAll(alongside, now)
        .whenComplete(() => _backupInFlight = null);
  }

  Future<({BackupResult library, BackupResult? alongside})> _backupAll(
    DriveSnapshotSource? alongside,
    DateTime? now,
  ) async {
    final api = await _apiProvider();
    if (api == null) return (library: const BackupNotSignedIn(), alongside: null);

    final library = await _uploadSnapshot(api, _LibrarySnapshots(repo), now);
    if (library is! BackupSucceeded) return (library: library, alongside: null);

    final families = [DriveArtifact.library];
    BackupResult? along;
    if (alongside != null) {
      along = await _changed(alongside)
          ? await _uploadSnapshot(api, alongside, now)
          : const BackupUnchanged();
      if (along is BackupSucceeded) families.add(alongside.artifact);
    }
    await _prune(api, families);
    return (library: library, alongside: along);
  }

  static Future<bool> _changed(DriveSnapshotSource source) async {
    final changed = await source.lastContentChange();
    final last = await source.lastDriveBackup();
    return changed != null && (last == null || changed.isAfter(last));
  }

  Future<BackupResult> _uploadSnapshot(
    drive.DriveApi api,
    DriveSnapshotSource source,
    DateTime? now,
  ) async {
    // Stamped before the copy: a write landing mid-upload is newer than
    // the stamp, so it goes up next time.
    final stamp = now ?? DateTime.now();
    final family = source.artifact;
    final tmp = await getTemporaryDirectory();
    final copy = File(p.join(
      tmp.path,
      '${family.prefix}upload-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    ));
    try {
      await source.writeSnapshot(copy);
      final created = await _upload(api, copy, family.snapshotName(stamp));
      await source.setLastDriveBackup(stamp);
      return BackupSucceeded(_toSnapshot(created));
    } on drive.DetailedApiRequestError catch (e) {
      return _apiFailure(e);
    } catch (e) {
      return BackupFailed(e.toString());
    } finally {
      try {
        if (await copy.exists()) await copy.delete();
      } catch (_) {}
    }
  }

  /// Newest first. Empty list when signed out (rather than throwing) so
  /// the UI can render "no backups yet" without a special case.
  Future<List<DriveSnapshot>> listSnapshots({
    DriveArtifact artifact = DriveArtifact.library,
  }) async {
    final api = await _apiProvider();
    if (api == null) return const [];
    final list = await api.files.list(
      spaces: 'appDataFolder',
      orderBy: 'modifiedTime desc',
      $fields: 'files(id,name,size,modifiedTime)',
      pageSize: 100,
    );
    return [
      for (final f in list.files ?? const <drive.File>[])
        if (artifact.owns(f.name)) _toSnapshot(f),
    ];
  }

  /// Streams [snapshot] into the family's pending-restore side-car. The
  /// next open of that database swaps it in for the live one. The live
  /// db is *not* touched here, so screens currently reading from it
  /// stay safe.
  Future<DriveRestoreResult> restoreFromSnapshot(
    DriveSnapshot snapshot, {
    DriveArtifact artifact = DriveArtifact.library,
  }) async {
    final api = await _apiProvider();
    if (api == null) return const DriveRestoreNotSignedIn();
    try {
      final media = await api.files.get(
        snapshot.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final pending = await artifact.local.pendingFile();
      await pending.parent.create(recursive: true);

      final sink = pending.openWrite();
      try {
        await sink.addStream(media.stream);
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Validate before leaving the file in place — without this, a
      // truncated download or schema-incompatible snapshot would brick
      // the next launch (the swap is unconditional once the pending
      // file exists).
      final reason = await artifact.local.validate(pending);
      if (reason != null) {
        try {
          await pending.delete();
        } catch (_) {}
        return DriveRestoreFailed(reason);
      }

      return const DriveRestoreStaged();
    } on drive.DetailedApiRequestError catch (e) {
      return DriveRestoreFailed('${e.status}: ${e.message ?? 'unknown'}');
    } catch (e) {
      return DriveRestoreFailed(e.toString());
    }
  }

  Future<drive.File> _upload(drive.DriveApi api, File file, String name) async {
    final media = drive.Media(
      file.openRead(),
      await file.length(),
      contentType: 'application/x-sqlite3',
    );
    final metadata = drive.File()
      ..name = name
      ..parents = ['appDataFolder']
      ..mimeType = 'application/x-sqlite3';
    return api.files.create(
      metadata,
      uploadMedia: media,
      $fields: 'id,name,size,modifiedTime',
    );
  }

  static BackupResult _apiFailure(drive.DetailedApiRequestError e) {
    final msg = (e.message ?? '').toLowerCase();
    if (e.status == 403 && msg.contains('quota')) {
      return const BackupQuotaExceeded();
    }
    return BackupFailed('${e.status}: ${e.message ?? 'unknown'}');
  }

  /// Keeps the [retentionCount] newest of each of [families], from one
  /// listing. Best effort: the uploads already landed.
  Future<void> _prune(
    drive.DriveApi api,
    List<DriveArtifact> families,
  ) async {
    try {
      final list = await api.files.list(
        spaces: 'appDataFolder',
        orderBy: 'modifiedTime desc',
        $fields: 'files(id,name)',
        pageSize: 100,
      );
      final files = list.files ?? const <drive.File>[];
      for (final family in families) {
        final stale = files.where((f) => family.owns(f.name)).skip(retentionCount);
        for (final f in stale) {
          final id = f.id;
          if (id != null) await api.files.delete(id);
        }
      }
    } catch (_) {}
  }

  static DriveSnapshot _toSnapshot(drive.File f) {
    return DriveSnapshot(
      id: f.id ?? '',
      name: f.name ?? '',
      size: int.tryParse(f.size ?? ''),
      modifiedTime: f.modifiedTime?.toLocal(),
    );
  }
}

class _LibrarySnapshots implements DriveSnapshotSource {
  _LibrarySnapshots(this.repo);

  final IunaRepository repo;

  @override
  DriveArtifact get artifact => DriveArtifact.library;

  @override
  String get label => 'library';

  /// Never consulted: the library always goes up.
  @override
  Future<DateTime?> lastContentChange() async => null;

  @override
  Future<DateTime?> lastDriveBackup() => repo.getLastDriveBackup();

  @override
  Future<void> setLastDriveBackup(DateTime ts) => repo.setLastDriveBackup(ts);

  @override
  Future<void> writeSnapshot(File target) => vacuumInto(repo.db, target);
}
