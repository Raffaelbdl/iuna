import 'package:flutter/material.dart';

import '../../services/dict_download.dart';
import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import 'remote_install.dart';

/// Settings → Dictionary: download, update or remove the JMdict sidecar
/// that the wishlist lookup, word taps and sentence games read. Also
/// offered from Collection's "+" before it is downloaded, where
/// [onReady] closes the offer once it is in.
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

  Future<void> _startInstall() async {
    final confirmed = await showConfirmDialog(
      context,
      title: _installed
          ? 'Update Japanese dictionary?'
          : 'Download Japanese dictionary?',
      body:
          'About 17 MB to download, ~45 MB stored on your phone. Wi-Fi '
          'recommended. It lets you look up any word to add to your '
          'wishlist, tap words in the tutor for their reading, and play '
          'the sentence games.',
      confirmLabel: _installed ? 'Update' : 'Download',
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
      return ListTile(
        leading: const Icon(icon, color: IunaPalette.pawBrown),
        title: const Text('Download dictionary'),
        subtitle: const Text(
          '~17 MB · look up any word to add to your wishlist, and play '
          'the sentence games.',
        ),
        trailing: FilledButton(
          onPressed: _startInstall,
          child: const Text('Download'),
        ),
      );
    }
    return ListTile(
      leading: const Icon(icon, color: IunaPalette.pawBrown),
      title: const Text('Dictionary installed'),
      subtitle: Text('$_sizeMb MB · build ${_version ?? '?'}'),
      trailing: OutlinedButton(
        onPressed: _startInstall,
        child: const Text('Update'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IunaGroup(
      'Dictionary (experimental)',
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
