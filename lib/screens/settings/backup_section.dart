import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../db/repository.dart';
import '../../db/sqlite_open.dart';
import '../../learn/learn.dart';
import '../../learn/learn_backup.dart';
import '../../services/db_restore.dart';
import '../../services/drive_auth.dart';
import '../../services/drive_sync.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import '../../widgets/time_words.dart';

/// Settings → Backup & restore and Cloud backup: save or restore a
/// backup file, Drive sign-in, back up now, and restore the collection
/// or the courses from Drive.
class BackupSection extends StatefulWidget {
  const BackupSection({super.key, required this.repo});

  final IunaRepository repo;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  IunaRepository get _repo => widget.repo;

  GoogleSignInAccount? _account;
  DateTime? _lastBackup;
  DateTime? _lastLearnBackup;
  bool _busy = false;
  StreamSubscription<GoogleSignInAccount?>? _accountSub;

  @override
  void initState() {
    super.initState();
    _account = DriveAuth.instance.currentUser;
    _accountSub = DriveAuth.instance.onUserChanged.listen((acc) {
      if (mounted) setState(() => _account = acc);
    });
    DriveAuth.instance.signInSilently();
    _loadStamps();
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStamps() async {
    final library = await _repo.getLastDriveBackup();
    if (mounted) setState(() => _lastBackup = library);
    // Apart from the library's: it may open the tutor's database.
    final courses = await Learn.instance.snapshots();
    final stamp = await courses?.lastDriveBackup();
    if (mounted) setState(() => _lastLearnBackup = stamp);
  }

  Future<bool> _confirmReplaceLibrary() => showConfirmDialog(
    context,
    title: 'Replace your collection?',
    body:
        'Your current cards, reviews, and progress will be replaced '
        'with the chosen backup. This cannot be undone from inside '
        'the app.',
    confirmLabel: 'Replace',
    destructive: true,
  );

  Future<bool> _confirmReplaceCourses() => showConfirmDialog(
    context,
    title: 'Replace your courses?',
    body:
        'Your current courses, chats and Kuma-sensei’s notes will be '
        'replaced with the chosen backup. Your cards are not touched.',
    confirmLabel: 'Replace',
    destructive: true,
  );

  Future<void> _restoreFromFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Pick a backup file from Iuna',
    );
    final path = picked?.files.firstOrNull?.path;
    if (path == null || !mounted) return;

    // Checked before asking, so nobody confirms replacing their
    // collection with a file that was never going to restore.
    final file = File(path);
    final reason = await kLibrarySnapshot.validate(file);
    if (!mounted) return;
    if (reason != null) {
      showErrorSnack(context, "That file isn't an Iuna backup.", reason);
      return;
    }

    final confirmed = await _confirmReplaceLibrary();
    if (!confirmed || !mounted) return;

    final RestoreOutcome result;
    try {
      result = await stagePendingRestore(file);
    } catch (e) {
      if (mounted) showErrorSnack(context, "Couldn't restore that file.", e);
      return;
    }
    if (!mounted) return;
    if (result is RestoreRejected) {
      showErrorSnack(context, "That file isn't an Iuna backup.", result.reason);
      return;
    }
    await _showStagedDialog();
  }

  /// Writes a copy of the collection where the learner picks, for a
  /// restore without Google Drive.
  Future<void> _saveToFile() async {
    setState(() => _busy = true);
    final dir = await Directory.systemTemp.createTemp('iuna_backup_');
    try {
      final copy = File('${dir.path}/iuna.sqlite');
      await vacuumInto(_repo.db, copy);
      final bytes = await copy.readAsBytes();
      final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save a backup file',
        fileName: 'iuna-backup-$day.sqlite',
        bytes: bytes,
      );
      // On a phone the picker writes the bytes; a desktop one only
      // names the file.
      if (path != null && !Platform.isAndroid && !Platform.isIOS) {
        await File(path).writeAsBytes(bytes, flush: true);
      }
      if (path != null && mounted) {
        showSnack(context, 'Backup saved. Restore it here any time.');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, "Couldn't save the backup.", e);
    } finally {
      unawaited(dir.delete(recursive: true));
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The restore lands on the next launch. Android can close the app
  /// from here; elsewhere the learner closes it.
  Future<void> _showStagedDialog({String what = 'collection'}) async {
    if (!mounted) return;
    final canClose = Platform.isAndroid;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore ready'),
        content: Text(
          canClose
              ? 'Iuna swaps in the restored $what the next time it opens. '
                    'Close it now, then open it again.'
              : 'Close and reopen Iuna to apply the restored $what. The '
                    'app will swap it in on next launch.',
        ),
        actions: [
          if (canClose) ...[
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Close Iuna now'),
            ),
          ] else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final AuthResult result;
    try {
      result = await DriveAuth.instance.signIn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    switch (result) {
      case AuthSigned():
        showSnack(context, 'Signed in to Google Drive');
      case AuthCancelled():
        // Silent — user knows they cancelled.
        break;
      case AuthDenied():
        showSnack(context, 'Drive access denied');
      case AuthNetworkError(:final message):
        showErrorSnack(
          context,
          "Couldn't reach Google. Check your connection.",
          message ?? 'network error',
        );
      case AuthFailed(:final message):
        showErrorSnack(context, "Couldn't sign in to Google Drive.", message);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await DriveAuth.instance.signOut();
    } catch (e) {
      if (mounted) showErrorSnack(context, "Couldn't sign out.", e);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) showSnack(context, 'Signed out of Google Drive');
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final courses = await Learn.instance.snapshots();
      final result = await DriveSync(_repo).backupAll(alongside: courses);
      final libraryStamp = await _repo.getLastDriveBackup();
      final learnStamp = await courses?.lastDriveBackup();
      if (!mounted) return;
      setState(() {
        _lastBackup = libraryStamp;
        _lastLearnBackup = learnStamp;
      });
      final message = backupMessage(result, alongside: courses);
      if (message != null) showSnack(context, message);
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, "Couldn't back up. Try again later.", e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(
    DriveArtifact artifact, {
    required String what,
    required Future<bool> Function() confirm,
  }) async {
    setState(() => _busy = true);
    final sync = DriveSync(_repo);
    final List<DriveSnapshot> snapshots;
    try {
      snapshots = await sync.listSnapshots(artifact: artifact);
    } catch (e) {
      if (mounted) {
        showErrorSnack(
          context,
          "Couldn't reach Google Drive. Check your connection.",
          e,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    if (snapshots.isEmpty) {
      showSnack(context, 'No backups on Drive yet');
      return;
    }

    final picked = await _showSnapshotPicker(snapshots);
    if (picked == null || !mounted) return;

    final confirmed = await confirm();
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final DriveRestoreResult result;
    try {
      result = await sync.restoreFromSnapshot(picked, artifact: artifact);
    } catch (e) {
      if (mounted) {
        showErrorSnack(
          context,
          "Couldn't download that backup. Try again later.",
          e,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;

    switch (result) {
      case DriveRestoreStaged():
        await _showStagedDialog(what: what);
      case DriveRestoreNotSignedIn():
        showSnack(context, 'Not signed in');
      case DriveRestoreFailed(:final message):
        showErrorSnack(
          context,
          "Couldn't download that backup. Try again later.",
          message,
        );
    }
  }

  Future<DriveSnapshot?> _showSnapshotPicker(List<DriveSnapshot> snapshots) {
    return showModalBottomSheet<DriveSnapshot>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const IunaSectionHeader('Restore from Drive'),
            for (final s in snapshots)
              ListTile(
                leading: const Icon(
                  Icons.cloud_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: Text(_humanDate(s.modifiedTime) ?? s.name),
                subtitle: Text(_humanSize(s.size)),
                onTap: () => Navigator.of(ctx).pop(s),
              ),
          ],
        ),
      ),
    );
  }

  static String? _humanDate(DateTime? ts) =>
      ts == null ? null : stampWords(ts.toLocal());

  static String _humanSize(int? bytes) {
    if (bytes == null) return 'unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _stamp(DateTime ts) => stampWords(ts);

  Widget get _spinner => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );

  @override
  Widget build(BuildContext context) {
    const chevron = Icon(Icons.chevron_right_rounded, color: IunaPalette.ink3);
    final account = _account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IunaGroup(
          'Backup & restore',
          children: [
            ListTile(
              leading: const Icon(
                Icons.save_alt_rounded,
                color: IunaPalette.pawBrown,
              ),
              title: const Text('Save a backup file'),
              subtitle: const Text(
                'A copy of your collection, reviews and progress, kept '
                'wherever you choose. Courses are not included.',
              ),
              trailing: chevron,
              enabled: !_busy,
              onTap: _saveToFile,
            ),
            ListTile(
              leading: const Icon(
                Icons.upload_file_rounded,
                color: IunaPalette.pawBrown,
              ),
              title: const Text('Restore from file'),
              subtitle: const Text(
                'Replace your collection with a backup file from Iuna. '
                'Takes effect after restart.',
              ),
              trailing: chevron,
              enabled: !_busy,
              onTap: _restoreFromFile,
            ),
          ],
        ),
        const SizedBox(height: 16),
        IunaGroup(
          'Cloud backup',
          children: [
            if (account == null)
              IunaControlTile(
                leading: const Icon(
                  Icons.cloud_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: const Text('Sign in with Google'),
                subtitle: const Text(
                  'Keep a copy of your collection in your own Google '
                  'Drive, made whenever you ask.',
                ),
                control: _busy
                    ? _spinner
                    : FilledButton(
                        onPressed: _signIn,
                        child: const Text('Sign in'),
                      ),
              )
            else ...[
              IunaControlTile(
                leading: const Icon(
                  Icons.account_circle_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: Text('Signed in: ${account.email}'),
                subtitle: Text(
                  _lastBackup == null
                      ? 'No backup yet'
                      : 'Last backed up: ${_stamp(_lastBackup!)}',
                ),
                control: _busy
                    ? _spinner
                    : OutlinedButton(
                        onPressed: _signOut,
                        child: const Text('Sign out'),
                      ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.cloud_upload_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: const Text('Back up now'),
                subtitle: const Text(
                  'Upload your collection to Google Drive; pulling down '
                  'on Home does it too. Courses go along whenever they '
                  'changed.',
                ),
                enabled: !_busy,
                onTap: _backup,
              ),
              ListTile(
                leading: const Icon(
                  Icons.cloud_download_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: const Text('Restore from Drive'),
                subtitle: const Text(
                  'Pick a backup to restore. Takes effect after restart.',
                ),
                trailing: chevron,
                enabled: !_busy,
                onTap: () => _restore(
                  DriveArtifact.library,
                  what: 'collection',
                  confirm: _confirmReplaceLibrary,
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: IunaPalette.pawBrown,
                ),
                title: const Text('Restore courses from Drive'),
                subtitle: Text(
                  _lastLearnBackup == null
                      ? 'Courses are backed up separately from your cards.'
                      : 'Courses last backed up: ${_stamp(_lastLearnBackup!)}',
                ),
                trailing: chevron,
                enabled: !_busy,
                onTap: () => _restore(
                  kCoursesArtifact,
                  what: 'courses',
                  confirm: _confirmReplaceCourses,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
