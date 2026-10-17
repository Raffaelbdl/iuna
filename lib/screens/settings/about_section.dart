import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/app_update.dart';
import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import 'remote_install.dart';

/// Settings → About: the installed version and, on Android, the update
/// check against GitHub Releases.
class AboutSection extends StatefulWidget {
  const AboutSection({super.key, this.updatable, this.client});

  /// Whether to offer the update check; defaults to
  /// [AppUpdate.supported].
  final bool? updatable;
  final http.Client? client;

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  late final bool _updatable = widget.updatable ?? AppUpdate.supported;
  String? _version;
  bool _checking = false;
  RemoteInstall? _install;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    final running = _updatable ? AppUpdate.current : null;
    if (running != null) {
      _install = running;
      _awaitInstall(running);
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = info.version);
  }

  Future<void> _check() async {
    final local = _version;
    if (local == null) return;
    setState(() => _checking = true);
    final AppRelease? release;
    try {
      release = await AppUpdate.check(local, client: widget.client);
    } catch (e) {
      if (mounted) showSnack(context, 'Update check failed: $e');
      return;
    } finally {
      if (mounted) setState(() => _checking = false);
    }
    if (!mounted) return;
    if (release == null) {
      showSnack(context, 'Iuna $local is up to date.');
      return;
    }
    final mb = (release.bytes / 1024 / 1024).toStringAsFixed(0);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Update to ${release.version}?',
      body:
          'About $mb MB to download from GitHub. Android then asks you '
          'to confirm the install. Your collection, reviews and Learn '
          'chats are kept.',
      confirmLabel: 'Update',
    );
    if (!confirmed || !mounted) return;
    final install = await AppUpdate.download(release, client: widget.client);
    if (!mounted) return;
    setState(() => _install = install);
    await _awaitInstall(install);
  }

  Future<void> _awaitInstall(RemoteInstall install) async {
    final error = await install.result;
    if (!mounted) return;
    setState(() => _install = null);
    if (error != null) showSnack(context, 'Update failed: $error');
  }

  Widget _updateTile() {
    const icon = Icons.system_update_outlined;
    final install = _install;
    if (install != null) {
      return RemoteInstallTile(
        install: install,
        icon: icon,
        title: 'Updating Iuna',
      );
    }
    return ListTile(
      leading: const Icon(icon, color: IunaPalette.pawBrown),
      title: const Text('Check for updates'),
      subtitle: Text(
        _checking ? 'Checking GitHub…' : 'Installs new releases from GitHub.',
      ),
      enabled: !_checking && _version != null,
      onTap: _check,
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = _version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const IunaSectionHeader('About'),
        ListTile(
          leading: const Icon(
            Icons.info_outline_rounded,
            color: IunaPalette.pawBrown,
          ),
          title: const Text('Iuna'),
          subtitle: version == null ? null : Text('Version $version'),
        ),
        if (_updatable) _updateTile(),
      ],
    );
  }
}
