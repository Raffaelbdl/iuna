import 'package:flutter/material.dart';

import '../../services/remote_asset.dart';
import '../../theme/iuna_theme.dart';

extension RemotePhaseLabel on RemotePhase {
  String get label => switch (this) {
    RemotePhase.fetchingVersion => 'Checking for updates…',
    RemotePhase.downloading => 'Downloading…',
    RemotePhase.verifying => 'Verifying…',
    RemotePhase.applying => 'Adding cards…',
    RemotePhase.done => 'Done',
    RemotePhase.failed => 'Failed',
  };
}

/// The progress of a running [RemoteInstall]. [title] heads the tile
/// when given; otherwise the phase does.
class RemoteInstallTile extends StatelessWidget {
  const RemoteInstallTile({
    super.key,
    required this.install,
    required this.icon,
    this.title,
  });

  final RemoteInstall install;
  final IconData icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RemoteProgress>(
      valueListenable: install,
      builder: (context, progress, _) {
        final phase = progress.phase.label;
        final bar = LinearProgressIndicator(value: progress.fraction);
        return ListTile(
          leading: Icon(icon, color: IunaPalette.pawBrown),
          title: Text(title ?? phase),
          subtitle: title == null
              ? bar
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(phase), const SizedBox(height: 6), bar],
                ),
        );
      },
    );
  }
}
