import 'package:flutter/material.dart';

import '../../services/tts.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/paper_sheet.dart';
import '../../widgets/sense_row.dart';
import '../../widgets/vocab_card.dart';
import '../words/segmenter.dart';

/// A tapped word from the tutor's message: its reading over it, its
/// meanings, and the other headwords the same text could be.
Future<void> showWordSheet(BuildContext context, String surface, TextWord word) =>
    showPaperSheet<void>(context, (_) => WordSheet(surface: surface, word: word));

class WordSheet extends StatefulWidget {
  const WordSheet({super.key, required this.surface, required this.word});

  /// The text as the tutor wrote it.
  final String surface;
  final TextWord word;

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  int _shown = 0;

  static const _maxOthers = 4;

  @override
  Widget build(BuildContext context) {
    final readings = widget.word.readings;
    final reading = readings[_shown];
    final hit = reading.entry;
    final others = [
      for (var i = 0; i < readings.length; i++)
        if (i != _shown) i,
    ].take(_maxOthers).toList();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHandle(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: _Headword(kanji: hit.kanji, kana: hit.kana),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Listen',
                          onPressed: () => TtsService.instance.speak(hit.kana),
                          icon: const Icon(Icons.volume_up_rounded, color: IunaPalette.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RarityChip(rarity: hit.rarity),
                  ),
                ],
              ),
              if (reading.inflections.isNotEmpty || hit.jlptLevel != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hit.jlptLevel != null) MetaChip(label: 'JLPT N${hit.jlptLevel}'),
                    if (reading.inflections.isNotEmpty)
                      Text(
                        '${widget.surface} · ${reading.inflections.join(' · ')}',
                        style: const TextStyle(fontSize: 12, color: IunaPalette.ink3),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JmdictSenseList(hit.senses),
                      if (others.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(0, 14, 0, 4),
                          child: Text(
                            'Could also be',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: IunaPalette.ink3,
                            ),
                          ),
                        ),
                        for (final i in others)
                          _Other(reading: readings[i], onTap: () => setState(() => _shown = i)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The headword with its reading set over it, as furigana sits.
class _Headword extends StatelessWidget {
  const _Headword({required this.kanji, required this.kana});

  final String kanji;
  final String kana;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kanji != kana)
          Text(kana, style: const TextStyle(fontSize: 14, color: IunaPalette.ink2, height: 1.2)),
        Text(
          kanji,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: IunaPalette.ink,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _Other extends StatelessWidget {
  const _Other({required this.reading, required this.onTap});

  final WordReading reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hit = reading.entry;
    final gloss = hit.senses.isEmpty ? '' : hit.senses.first.gloss;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(IunaRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: hit.kanji,
                style: const TextStyle(fontWeight: FontWeight.w700, color: IunaPalette.ink),
              ),
              if (hit.kanji != hit.kana)
                TextSpan(
                  text: '  ${hit.kana}',
                  style: const TextStyle(color: IunaPalette.ink2),
                ),
              TextSpan(
                text: '  $gloss',
                style: const TextStyle(color: IunaPalette.ink3),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
    );
  }
}
