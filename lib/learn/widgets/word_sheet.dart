import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../db/jmdict_lookup.dart';
import '../../db/repository.dart';
import '../../services/tts.dart';
import '../../theme/iuna_theme.dart';
import '../../widgets/cta_button.dart';
import '../../widgets/paper_sheet.dart';
import '../../widgets/sense_row.dart';
import '../../widgets/snack.dart';
import '../../widgets/vocab_card.dart';
import '../deck.dart';
import '../words/segmenter.dart';

/// A tapped word from the tutor's message: its reading over it, its
/// meanings, and the other headwords the same text could be. With
/// [bookmarks], a word not yet collected can be wishlisted from it.
Future<void> showWordSheet(
  BuildContext context,
  String surface,
  TextWord word, {
  WordBookmarks? bookmarks,
}) {
  HapticFeedback.selectionClick();
  // Closing the sheet hands focus back to whatever held it, and a
  // message box that kept focus behind a hidden keyboard would pop it
  // open again and scroll the chat away from the word.
  FocusManager.instance.primaryFocus?.unfocus();
  return showPaperSheet<void>(
    context,
    (_) => WordSheet(surface: surface, word: word, bookmarks: bookmarks),
  );
}

class WordSheet extends StatefulWidget {
  const WordSheet({super.key, required this.surface, required this.word, this.bookmarks});

  /// The text as the tutor wrote it.
  final String surface;
  final TextWord word;

  /// Where a word not yet collected can be bookmarked.
  final WordBookmarks? bookmarks;

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
                        style: IunaText.caption.copyWith(color: IunaPalette.ink3),
                      ),
                  ],
                ),
              ],
              if (widget.bookmarks case final bookmarks?) ...[
                const SizedBox(height: 10),
                _DeckAction(key: ValueKey((hit.kanji, hit.kana)), bookmarks: bookmarks, entry: hit),
              ],
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JmdictSenseList(hit.senses),
                      if (others.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(0, 14, 0, 4),
                          child: Text(
                            'Could also be',
                            style: IunaText.chip.copyWith(
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
          Text(kana, style: IunaText.body.copyWith(color: IunaPalette.ink2, height: 1.2)),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
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
                style: IunaText.bodySmall.copyWith(height: 1.4),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: IunaPalette.ink3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the word stands in the learner's deck, as Add card shows it,
/// and a Bookmark button while it isn't theirs or wished for yet.
class _DeckAction extends StatefulWidget {
  const _DeckAction({super.key, required this.bookmarks, required this.entry});

  final WordBookmarks bookmarks;
  final JmdictHit entry;

  @override
  State<_DeckAction> createState() => _DeckActionState();
}

class _DeckActionState extends State<_DeckAction> {
  CardLookupStatus? _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.bookmarks.status(widget.entry.kanji, widget.entry.kana).then(_show);
  }

  void _show(CardLookupStatus status) {
    if (mounted) setState(() => _status = status);
  }

  Future<void> _bookmark() async {
    setState(() => _busy = true);
    try {
      _show(await widget.bookmarks.wishlist(widget.entry));
    } catch (e) {
      if (mounted) {
        showErrorSnack(context, "Couldn't add it to your wishlist.", e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null) return const SizedBox(height: 40);
    final open = status == CardLookupStatus.notFound || status == CardLookupStatus.available;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        CardStatusChip(status: status),
        if (open)
          IunaGhostButton(
            label: 'Add to wishlist',
            leadingIcon: Icons.bookmark_add_outlined,
            shrinkWrap: true,
            onTap: _busy ? null : _bookmark,
          ),
      ],
    );
  }
}
