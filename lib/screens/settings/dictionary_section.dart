import 'package:flutter/material.dart';

import '../../services/dict_download.dart';
import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import 'remote_install.dart';

/// A sheet that offers the dictionary where a feature needs it: what
/// it would do ([title], [body]) and the download. True once it is in.
Future<bool> showDictionaryOffer(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final ready = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                title,
                style: IunaText.title.copyWith(color: IunaPalette.ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              child: Text(
                body,
                style: IunaText.body.copyWith(
                  color: IunaPalette.ink2,
                  height: 1.4,
                ),
              ),
            ),
            DictionarySection(onReady: () => Navigator.of(ctx).pop(true)),
          ],
        ),
      ),
    ),
  );
  return ready ?? false;
}

/// Settings → Dictionary: download, update or remove the JMdict sidecar
/// that the wishlist lookup, word taps and sentence games read. Also
/// inside [showDictionaryOffer], where [onReady] closes the offer once
/// it is in.
class DictionarySection extends StatefulWidget {
  const DictionarySection({super.key, this.onReady});

  final VoidCallback? onReady;

  @override
  State<DictionarySection> createState() => _DictionarySectionState();
}

class _DictionarySectionState extends State<DictionarySection> {
  bool _installed = false;
  String? _version;
  int _bytes = 0;
  RemoteInstall? _install;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    final running = DictDownload.current;
    if (running != null) {
      _install = running;
      _awaitInstall(running);
    }
  }

  Future<void> _refresh() async {
    final (installed, version, bytes) = await (
      DictDownload.isInstalled(),
      DictDownload.localVersion(),
      DictDownload.installedSize(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _version = version;
      _bytes = bytes;
    });
  }

  String get _sizeMb => (_bytes / 1024 / 1024).toStringAsFixed(1);

  /// Asks the server for its version first, so an installed dictionary
  /// that is current costs no download.
  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    final String? remote;
    try {
      remote = await DictDownload.remoteVersion();
    } catch (e) {
      if (mounted) {
        showErrorSnack(
          context,
          "Couldn't check for an update. Check your connection.",
          e,
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    if (remote == _version) {
      showSnack(context, 'Your dictionary is up to date.');
      return;
    }
    await _startInstall();
  }

  Future<void> _startInstall() async {
    final confirmed = await showConfirmDialog(
      context,
      title: _installed
          ? 'A new dictionary is out'
          : 'Download Japanese dictionary?',
      body: _installed
          ? 'About 17 MB to download, Wi-Fi recommended. It replaces the '
                'one on your phone.'
          : 'About 17 MB to download, ~45 MB stored on your phone. Wi-Fi '
                'recommended. It lets you look up any word to add to your '
                'wishlist, tap words in the tutor for their reading, and '
                'play the sentence games.',
      confirmLabel: 'Download',
    );
    if (!confirmed || !mounted) return;
    final install = DictDownload.install();
    setState(() => _install = install);
    await _awaitInstall(install);
  }

  Future<void> _awaitInstall(RemoteInstall install) async {
    final error = await install.result;
    if (!mounted) return;
    setState(() => _install = null);
    if (error == null) {
      await _refresh();
      if (!mounted) return;
      showSnack(context, 'Dictionary ready.');
      widget.onReady?.call();
    } else {
      showErrorSnack(
        context,
        "The dictionary didn't download. Check your connection.",
        error,
        action: SnackBarAction(label: 'Retry', onPressed: _startInstall),
      );
    }
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove the dictionary?',
      body:
          'Deletes the offline dictionary from your phone. Looking up '
          'words for your wishlist, word taps in the tutor and the '
          'sentence games stop working until you download it again. Your '
          'collection is not affected.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed) return;
    await DictDownload.uninstall();
    await _refresh();
    if (mounted) showSnack(context, 'Dictionary removed.');
  }

  Widget _tile() {
    const icon = Icons.book_outlined;
    final install = _install;
    if (install != null) return RemoteInstallTile(install: install, icon: icon);
    if (!_installed) {
      return IunaControlTile(
        leading: const Icon(icon, color: IunaPalette.pawBrown),
        title: const Text('Download dictionary'),
        subtitle: const Text(
          '~17 MB · look up any word to add to your wishlist, and play '
          'the sentence games.',
        ),
        control: FilledButton(
          onPressed: _startInstall,
          child: const Text('Download'),
        ),
      );
    }
    return IunaControlTile(
      leading: const Icon(icon, color: IunaPalette.pawBrown),
      title: const Text('Dictionary installed'),
      subtitle: Text('$_sizeMb MB on your phone'),
      control: OutlinedButton(
        onPressed: _checking ? null : _checkForUpdate,
        child: Text(_checking ? 'Checking…' : 'Update'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IunaGroup(
      'Dictionary',
      children: [
        _tile(),
        if (_installed && _install == null)
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: IunaPalette.pawBrown,
            ),
            title: const Text('Remove dictionary'),
            subtitle: Text(_bytes > 0 ? '$_sizeMb MB on disk' : ''),
            onTap: _clear,
          ),
      ],
    );
  }
}
