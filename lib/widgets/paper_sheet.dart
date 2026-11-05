import 'package:flutter/material.dart';

import '../theme/iuna_theme.dart';

/// A bottom sheet on paper with rounded top corners, as a dictionary
/// entry opens.
Future<T?> showPaperSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: IunaPalette.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: builder,
  );
}

/// The drag handle at the top of a [showPaperSheet] sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: IunaPalette.ink3.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
