import 'package:flutter/material.dart';

import '../../db/database.dart';
import '../../db/repository.dart';
import '../../services/pack_download.dart';
import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/section_header.dart';
import '../../widgets/snack.dart';
import 'remote_install.dart';

/// Settings → Card packs: the remote catalogue, Add / Update, and the
/// credits of every installed pack. Hidden while there is nothing to
/// list.
class CardPacksSection extends StatefulWidget {
  const CardPacksSection({
    super.key,
    required this.repo,
    required this.onInstalled,
  });

  final IunaRepository repo;

  /// A pack landed: the draw filter has a new choice.
  final VoidCallback onInstalled;

  @override
  State<CardPacksSection> createState() => _CardPacksSectionState();
}

class _CardPacksSectionState extends State<CardPacksSection> {
  List<PackRow> _installed = const [];
  List<PackListing> _catalogue = const [];

  /// Installs this section shows, by pack name. One at a time: a second
  /// would race the first's transaction for nothing.
  final Map<String, RemoteInstall> _installs = {};

  @override
  void initState() {
    super.initState();
    _loadInstalled();
    _loadCatalogue();
    _installs.addAll(PackDownload.running);
    _installs.forEach(_awaitInstall);
  }

  Future<void> _loadInstalled() async {
    final installed = await widget.repo.installedPacks();
    if (mounted) setState(() => _installed = installed);
  }

  Future<void> _loadCatalogue() async {
    final listings = await PackDownload.catalogue();
    if (mounted) setState(() => _catalogue = listings);
  }

  void _install(PackListing listing) {
    final install = PackDownload.install(listing, widget.repo);
    setState(() => _installs[listing.name] = install);
    _awaitInstall(listing.name, install);
  }

  Future<void> _awaitInstall(String name, RemoteInstall install) async {
    final error = await install.result;
    if (!mounted) return;
    setState(() => _installs.remove(name));
    final label =
        _catalogue.where((l) => l.name == name).firstOrNull?.label ?? name;
    if (error == null) {
      await _loadInstalled();
      widget.onInstalled();
      if (mounted) showSnack(context, '$label installed.');
    } else {
      showSnack(context, 'Pack failed: $error');
    }
  }

  Widget _tile(PackListing listing) {
    const icon = Icons.category_rounded;
    final install = _installs[listing.name];
    if (install != null) {
      return RemoteInstallTile(
        install: install,
        icon: icon,
        title: listing.label,
      );
    }
    final onAdd = _installs.isEmpty ? () => _install(listing) : null;

    final installed = _installed
        .where((p) => p.name == listing.name)
        .firstOrNull;
    final upToDate = installed != null && installed.version == listing.version;
    final credit = _credit(
      listing.sourceTitle,
      listing.sourceAuthor,
      listing.license,
    );
    const creditStyle = TextStyle(fontSize: 11, color: IunaPalette.inkMute);

    return ListTile(
      leading: const Icon(icon, color: IunaPalette.pawBrown),
      title: Text(listing.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listing.description.isEmpty
                ? '${listing.cards} cards'
                : '${listing.description} · ${listing.cards} cards',
          ),
          if (credit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('Source: $credit', style: creditStyle),
          ],
          if (listing.sourceUrl != null)
            Text(listing.sourceUrl!, style: creditStyle),
        ],
      ),
      trailing: upToDate
          ? const Icon(Icons.check_circle_rounded, color: IunaPalette.pawBrown)
          : (installed == null
                ? FilledButton(onPressed: onAdd, child: const Text('Add'))
                : OutlinedButton(
                    onPressed: onAdd,
                    child: const Text('Update'),
                  )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_catalogue.isEmpty && _installed.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const IunaSectionHeader('Card packs'),
        for (final listing in _catalogue) _tile(listing),
        // A pack installed from a catalogue entry that has since been
        // withdrawn still deserves its credit line.
        for (final pack in _installed)
          if (!_catalogue.any((l) => l.name == pack.name))
            _InstalledPackTile(pack: pack),
      ],
    );
  }
}

String _credit(String? title, String? author, String? license) => [
  ?title,
  if (author != null) 'by $author',
  ?license,
].join(' · ');

/// An installed pack the remote catalogue no longer lists. Read-only —
/// packs are never removed, so this is purely the attribution record.
class _InstalledPackTile extends StatelessWidget {
  const _InstalledPackTile({required this.pack});
  final PackRow pack;

  @override
  Widget build(BuildContext context) {
    final credit = _credit(pack.sourceTitle, pack.sourceAuthor, pack.license);
    return ListTile(
      leading: const Icon(Icons.category_rounded, color: IunaPalette.pawBrown),
      title: Text(pack.label),
      subtitle: Text(
        [
          '${pack.cardCount} cards',
          if (credit.isNotEmpty) 'Source: $credit',
          if (pack.sourceUrl != null) pack.sourceUrl!,
        ].join('\n'),
      ),
      trailing: const Icon(
        Icons.check_circle_rounded,
        color: IunaPalette.pawBrown,
      ),
    );
  }
}
