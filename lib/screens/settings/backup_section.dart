import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../db/repository.dart';
import '../../learn/learn.dart';
import '../../learn/learn_backup.dart';
import '../../services/db_restore.dart';
import '../../services/drive_auth.dart';
import '../../services/drive_sync.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';

/// Settings → Backup & restore and Cloud backup: restore from a file,
/// Drive sign-in, back up now, and restore the library or the courses
/// from Drive.
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
    title: 'Replace your library?',
    body:
        'Your current cards, reviews, and progress will be replaced '
        'with the chosen snapshot. This cannot be undone from inside '
        'the app.',
    confirmLabel: 'Replace',
  );

  Future<bool> _confirmReplaceCourses() => showConfirmDialog(
    context,
    title: 'Replace your courses?',
    body:
        'Your current courses, chats and Kuma-sensei’s notes will be '
        'replaced with the chosen snapshot. Your cards are not touched.',
    confirmLabel: 'Replace',
  );

  Future<void> _restoreFromFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: 'Pick an Iuna sqlite snapshot',
    );
    final path = picked?.files.firstOrNull?.path;
    if (path == null || !mounted) return;

    final confirmed = await _confirmReplaceLibrary();
    if (!confirmed || !mounted) return;

    final result = await stagePendingRestore(File(path));
    if (!mounted) return;
    if (result is RestoreRejected) {
      showSnack(context, 'Restore failed: ${result.reason}');
      return;
    }
    await _showStagedDialog();
  }

  Future<void> _showStagedDialog({String what = 'library'}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Snapshot staged'),
        content: Text(
          'Close and reopen Iuna to apply the restored $what. The '
          'app will swap it in on next launch.',
        ),
        actions: [
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
    final result = await DriveAuth.instance.signIn();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case AuthSigned():
        showSnack(context, 'Signed in to Google Drive');
      case AuthCancelled():
        // Silent — user knows they cancelled.
        break;
      case AuthDenied():
        showSnack(context, 'Drive access denied');
      case AuthNetworkError(:final message):
        showSnack(context, 'Network error: ${message ?? 'check connection'}');
      case AuthFailed(:final message):
        showSnack(context, 'Sign-in failed: $message');
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    await DriveAuth.instance.signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, 'Signed out of Google Drive');
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    final courses = await Learn.instance.snapshots();
    final result = await DriveSync(_repo).backupAll(alongside: courses);
    final libraryStamp = await _repo.getLastDriveBackup();
    final learnStamp = await courses?.lastDriveBackup();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastBackup = libraryStamp;
      _lastLearnBackup = learnStamp;
    });
    final message = backupMessage(result, alongside: courses);
    if (message != null) showSnack(context, message);
  }

  Future<void> _restore(
    DriveArtifact artifact, {
    required String what,
    required Future<bool> Function() confirm,
  }) async {
    setState(() => _busy = true);
    final sync = DriveSync(_repo);
    final snapshots = await sync.listSnapshots(artifact: artifact);
    if (!mounted) return;
    setState(() => _busy = false);

    if (snapshots.isEmpty) {
      showSnack(context, 'No snapshots on Drive yet');
      return;
    }

    final picked = await _showSnapshotPicker(snapshots);
    if (picked == null || !mounted) return;

    final confirmed = await confirm();
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    final result = await sync.restoreFromSnapshot(picked, artifact: artifact);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case DriveRestoreStaged():
        await _showStagedDialog(what: what);
      case DriveRestoreNotSignedIn():
        showSnack(context, 'Not signed in');
      case DriveRestoreFailed(:final message):
        showSnack(context, 'Restore failed: $message');
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

  static String? _humanDate(DateTime? ts) {
    if (ts == null) return null;
    return DateFormat('MMM d, HH:mm').format(ts.toLocal());
  }

  static String _humanSize(int? bytes) {
    if (bytes == null) return 'unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  static String _stamp(DateTime ts) =>
      DateFormat('yyyy-MM-dd HH:mm').format(ts);

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
        const IunaSectionHeader('Backup & restore'),
        ListTile(
          leading: const Icon(
            Icons.upload_file_rounded,
            color: IunaPalette.pawBrown,
          ),
          title: const Text('Restore from file'),
          subtitle: const Text(
            'Replace your library with an Iuna sqlite snapshot. '
            'Takes effect after restart.',
          ),
          trailing: chevron,
          onTap: _restoreFromFile,
        ),
        const SizedBox(height: 16),
        const IunaSectionHeader('Cloud backup'),
        if (account == null)
          ListTile(
            leading: const Icon(
              Icons.cloud_outlined,
              color: IunaPalette.pawBrown,
            ),
            title: const Text('Sign in with Google'),
            subtitle: const Text(
              'Save your collection to your own Google Drive.',
            ),
            trailing: _busy
                ? _spinner
                : FilledButton(
                    onPressed: _signIn,
                    child: const Text('Sign in'),
                  ),
          )
        else ...[
          ListTile(
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
            trailing: _busy
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
              'Upload your library to Google Drive. Courses go '
              'along whenever they changed.',
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
              'Pick a snapshot to stage. Takes effect after restart.',
            ),
            trailing: chevron,
            enabled: !_busy,
            onTap: () => _restore(
              DriveArtifact.library,
              what: 'library',
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
    );
  }
}
