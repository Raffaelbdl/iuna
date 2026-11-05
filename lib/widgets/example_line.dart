import 'package:flutter/material.dart';

import '../db/database.dart';
import '../theme/iuna_theme.dart';

/// One example sentence, with its English underneath when it has one.
class ExampleLine extends StatelessWidget {
  const ExampleLine({super.key, required this.example});

  final ExampleRow example;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '・${example.sentence}',
            style: const TextStyle(fontSize: 14, color: IunaPalette.ink2, height: 1.6),
          ),
          if (example.translation case final translation?)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                translation,
                style: const TextStyle(fontSize: 12, color: IunaPalette.ink3, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
