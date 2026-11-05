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

/// A Settings row with a control (a button, a dropdown) on the right,
/// or under its description once large text would squeeze the text
/// beside it to a word a line.
class IunaControlTile extends StatelessWidget {
  const IunaControlTile({
    super.key,
    required this.leading,
    required this.title,
    required this.control,
    this.subtitle,
  });

  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final below = context.textScaledPast(IunaTextScale.controlBelow);
    final subtitle = this.subtitle;
    return ListTile(
      leading: leading,
      title: title,
      subtitle: !below
          ? subtitle
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?subtitle,
                const SizedBox(height: 8),
                control,
              ],
            ),
      trailing: below ? null : control,
    );
  }
}

/// The small upper-cased caption over a group of things outside a
/// panel (Home's recent cards, the session recap, a game's misses), as
/// [IunaSectionHeader] is in Settings. Inside a panel, the title is an
/// [IunaPanelTitle].
class IunaEyebrow extends StatelessWidget {
  const IunaEyebrow(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: IunaText.eyebrow.copyWith(color: IunaPalette.ink3),
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

/// The title inside a paper panel (Stats cards, card detail's
/// sections, the review sheet): title case, bold, in ink.
class IunaPanelTitle extends StatelessWidget {
  const IunaPanelTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: IunaText.label.copyWith(
        fontWeight: FontWeight.w700,
        color: IunaPalette.ink,
      ),
    );
  }
}
