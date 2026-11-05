import 'package:flutter/material.dart';

import '../../widgets/option_tile.dart';
import '../agent/quiz.dart';

/// The options of a question the tutor asked in chat, plus the "I don't
/// know" every question offers. A tap answers with the option's text.
class ChoiceButtons extends StatelessWidget {
  const ChoiceButtons({super.key, required this.options, this.reply, this.onChoose});

  final List<String> options;

  /// The learner's reply, once given: the option it matches stays marked.
  final String? reply;

  /// Null while the question can't be answered: already answered, or
  /// Kuma-sensei is still talking.
  final ValueChanged<String>? onChoose;

  @override
  Widget build(BuildContext context) {
    final chosen = reply?.trim();
    final choose = onChoose;
    // The pick is marked as the learner's, never as right: Kuma-sensei's
    // next message says whether it was.
    Widget choice(String label, {bool quiet = false}) => OptionTile(
      label: label,
      quiet: quiet,
      selected: label == chosen,
      faded: chosen != null && label != chosen,
      tag: label == chosen ? 'Your answer' : null,
      onTap: choose == null ? null : () => choose(label),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final o in options)
          Padding(padding: const EdgeInsets.only(top: 8), child: choice(o)),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: choice(kDefaultSkipLabel, quiet: true),
        ),
      ],
    );
  }
}
