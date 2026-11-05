import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// Upper-cased section label, as in Settings. [trailing] sits on the
/// right (e.g. an "Add" button).
class IunaSectionHeader extends StatelessWidget {
  const IunaSectionHeader(
    this.title, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: IunaPalette.ink3,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
    );
    return Padding(
      padding: padding,
      child: trailing == null
          ? label
          : Row(children: [Expanded(child: label), trailing!]),
    );
  }
}

/// The small upper-cased caption over a card's section (home strip, card
/// detail, review sheet, session recap).
class IunaEyebrow extends StatelessWidget {
  const IunaEyebrow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: IunaPalette.ink3,
      ),
    );
  }
}

/// A titled group of rows on a paper panel, as in Settings.
class IunaGroup extends StatelessWidget {
  const IunaGroup(this.title, {super.key, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(IunaRadii.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IunaSectionHeader(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: paperPanelDecoration(borderRadius: radius),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
