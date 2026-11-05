import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';
import 'iuna_icon_button.dart';

/// The header of a tab root (Home, Collection, Learn): its [title] on
/// the left after an optional [leading] mark, [actions] on the right.
/// No back button: the system Back still leaves the tab.
class IunaTabHeader extends StatelessWidget {
  const IunaTabHeader(
    this.title, {
    super.key,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 10, 2),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(
            IunaIconButton.size,
            MediaQuery.textScalerOf(context).scale(28),
          ),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 10)],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IunaText.headline,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Iuna's い mark, ahead of the Home header.
class IunaLogoMark extends StatelessWidget {
  const IunaLogoMark({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [IunaPalette.heroTop, IunaPalette.bowPink],
          ),
          borderRadius: BorderRadius.circular(IunaRadii.sm),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(120, 40, 60, 0.18),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            'い',
            style: IunaText.label.copyWith(
              color: Color(0xFF5A3210),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
