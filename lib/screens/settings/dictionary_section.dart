import 'package:flutter/material.dart';

import '../../services/dict_download.dart';
import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import 'remote_install.dart';

/// Settings → Dictionary: download, update or clear the JMdict sidecar
/// that "Add card" looks words up in.
class DictionarySection extends StatefulWidget {
  const DictionarySection({super.key});

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
          'About 17 MB to download, ~45 MB stored locally after '
          'decompression. Wi-Fi recommended. Used by the experimental '
          '"Add card" flow to look up any JMdict entry.',
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
      if (mounted) showSnack(context, 'Dictionary ready.');
    } else {
      showSnack(context, 'Download failed: $error');
    }
  }

  Future<void> _clear() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear dictionary cache?',
      body:
          'Removes the offline JMdict lookup. The "Add card" flow will '
          'be unavailable until you download it again. Your collection '
          'is not affected.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) return;
    await DictDownload.uninstall();
    await _refresh();
    if (mounted) showSnack(context, 'Dictionary cleared.');
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
          '~17 MB · enables looking up any JMdict entry to add to '
          'your collection.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IunaSectionHeader('Dictionary (experimental)'),
        _tile(),
        if (_installed && _install == null)
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: IunaPalette.pawBrown,
            ),
            title: const Text('Clear dictionary cache'),
            subtitle: Text(_bytes > 0 ? '$_sizeMb MB on disk' : ''),
            onTap: _clear,
          ),
      ],
    );
  }
}
