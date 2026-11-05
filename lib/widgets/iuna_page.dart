import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';
import 'iuna_icon_button.dart';

/// A pushed screen in the app's own chrome: the page background, an
/// [IunaTopBar] with a back chevron, [title] and [trailing], then
/// [below] (a tab bar) and [body].
class IunaPage extends StatelessWidget {
  const IunaPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.trailing,
    this.below,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? below;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              IunaTopBar(
                leading: const IunaBackButton(),
                title: IunaTopBarTitle(title, subtitle: subtitle),
                trailing: trailing,
              ),
              ?below,
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// The back chevron of a pushed screen.
class IunaBackButton extends StatelessWidget {
  const IunaBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IunaIconButton(
      icon: Icons.chevron_left_rounded,
      tooltip: 'Back',
      onTap: () => Navigator.of(context).maybePop(),
    );
  }
}

/// A top bar's title, with an optional smaller line under it.
class IunaTopBarTitle extends StatelessWidget {
  const IunaTopBarTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IunaText.subtitle.copyWith(
            color: IunaPalette.ink2,
            letterSpacing: 0.6,
            height: 1.2,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: IunaText.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: IunaPalette.ink3,
              height: 1.2,
            ),
          ),
      ],
    );
  }
}
