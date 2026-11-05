import 'package:flutter/widgets.dart';

/// A custom-drawn control. [child] takes the taps and reads to a screen
/// reader as one button, its text merged into the label; [selected]
/// marks a toggle's state and [label] names an icon-only control.
class Tappable extends StatelessWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.selected,
    this.expanded,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? label;
  final bool? selected;

  /// For a row that opens more below it.
  final bool? expanded;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: onTap != null,
        selected: selected,
        expanded: expanded,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: child,
        ),
      ),
    );
  }
}
