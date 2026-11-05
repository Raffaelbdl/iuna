import 'dart:async';

import 'package:flutter/material.dart';

import '../core/japanese_text.dart';
import '../db/database.dart';
import '../db/jmdict_lookup.dart';
import '../db/repository.dart';
import '../services/dict_download.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/iuna_page.dart';
import '../widgets/paper_sheet.dart';
import '../widgets/search_field.dart';
import '../widgets/sense_row.dart';
import '../widgets/snack.dart';
import '../widgets/vocab_card.dart';
import 'card_detail_screen.dart';
import 'settings/dictionary_section.dart';

enum _SheetAction { cancel, promote, openCard }

/// The wishlist lookup, or, until the dictionary is downloaded, a sheet
/// that offers it first. Completes once the learner is back.
Future<void> openAddToWishlist(
  BuildContext context,
  AppDatabase db, {
  String? initialQuery,
  bool dictInstalled = false,
}) async {
  final navigator = Navigator.of(context);
  if (!dictInstalled && !await DictDownload.isInstalled()) {
    if (!context.mounted) return;
    final ready = await showDictionaryOffer(
      context,
      title: 'Add any word to your wishlist',
      body:
          'Look a word up in the offline dictionary and bookmark it. It '
          'shows up in a pack soon. The dictionary is a one-time download.',
    );
    if (ready != true) return;
  }
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => AddCardScreen(db: db, initialQuery: initialQuery),
    ),
  );
}

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key, required this.db, this.initialQuery});

  final AppDatabase db;
  final String? initialQuery;

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialQuery ?? '',
  );

  late String _query = widget.initialQuery ?? '';
  Timer? _debounce;
  List<JmdictHit> _results = const [];

  /// For a query in English: the deck's own cards with it in their
  /// meaning, as Collection's search finds them.
  List<CollectionEntry> _byMeaning = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Open the lookup eagerly so the first keystroke isn't slowed by
    // sqlite open + Android NDK workaround.
    JmdictLookup.instance.warmUp();
    if (_query.isNotEmpty) {
      _runSearch(_query);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String value) async {
    final q = value.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _byMeaning = const [];
        _searching = false;
      });
      return;
    }
    if (!japaneseRun.hasMatch(q)) {
      setState(() {
        _results = const [];
        _searching = true;
      });
      List<CollectionEntry> matches;
      try {
        matches = _byWholeWord(
          await _repo.ownedCards(query: q, includeUnowned: true),
          q,
        );
      } catch (e) {
        if (mounted) showErrorSnack(context, "Couldn't search your cards.", e);
        matches = const [];
      }
      if (!mounted || _query.trim() != q) return;
      setState(() {
        _byMeaning = matches.take(50).toList();
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    List<JmdictHit> hits;
    try {
      hits = await JmdictLookup.instance.search(q, limit: 50);
    } catch (e) {
      if (mounted) showErrorSnack(context, "Couldn't search the dictionary.", e);
      hits = const [];
    }
    if (!mounted || _query.trim() != q) return;
    setState(() {
      _results = hits;
      _byMeaning = const [];
      _searching = false;
    });
  }

  /// "cat" as a word before "category" or "educate".
  static List<CollectionEntry> _byWholeWord(List<CollectionEntry> entries, String q) {
    final word = RegExp('\\b${RegExp.escape(q)}\\b', caseSensitive: false);
    return [
      ...entries.where((e) => word.hasMatch(e.card.meaning)),
      ...entries.where((e) => !word.hasMatch(e.card.meaning)),
    ];
  }

  Future<void> _openCard(int cardId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(db: widget.db, cardId: cardId),
      ),
    );
    if (mounted) await _runSearch(_query);
  }

  Future<void> _previewAndAdd(JmdictHit hit) async {
    final lookup = await _repo.lookupByHeadword(hit.kanji, hit.kana);
    if (!mounted) return;

    final action = await showPaperSheet<_SheetAction>(
      context,
      (ctx) => _PreviewSheet(hit: hit, lookup: lookup),
    );
    if (!mounted || action == null || action == _SheetAction.cancel) return;

    switch (action) {
      case _SheetAction.openCard:
        if (lookup.cardId == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CardDetailScreen(db: widget.db, cardId: lookup.cardId!),
          ),
        );
      case _SheetAction.promote:
        await _repo.promoteFromJmdict(hit);
        if (!mounted) return;
        showSnack(
          context,
          '${hit.kanji} is on your wishlist — it shows up in a pack soon.',
        );
      case _SheetAction.cancel:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 7)),
            Column(
              children: [
                _buildAppBar(),
                _buildSearchBar(),
                Expanded(child: _buildResults()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return const IunaTopBar(
      leading: IunaBackButton(),
      title: IunaTopBarTitle('Add to wishlist'),
    );
  }

  Widget _buildSearchBar() {
    return IunaSearchField(
      controller: _ctrl,
      hint: 'kanji or kana — e.g. 早合点 or はやがてん',
      autofocus: true,
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      onChanged: _onChanged,
    );
  }

  Widget _buildResults() {
    if (_query.trim().isEmpty) {
      return const _EmptyState(
        icon: Icons.search_rounded,
        text:
            'Search the dictionary for a word. Add it to your wishlist '
            'and it shows up in a pack soon.',
      );
    }
    if (_searching && _results.isEmpty && _byMeaning.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!japaneseRun.hasMatch(_query)) {
      if (_byMeaning.isEmpty) {
        return const _EmptyState(
          icon: Icons.translate_rounded,
          text:
              'The dictionary looks words up in Japanese. Type the word in '
              'kanji or kana.',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _byMeaning.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => i == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  'The dictionary looks words up in Japanese. These cards '
                  'match by meaning:',
                  style: IunaText.bodySmall.copyWith(
                    color: IunaPalette.ink3,
                    height: 1.35,
                  ),
                ),
              )
            : _DeckTile(
                entry: _byMeaning[i - 1],
                onTap: () => _openCard(_byMeaning[i - 1].card.id),
              ),
      );
    }
    if (_results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        text: 'No matching entries.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ResultTile(
        hit: _results[i],
        onTap: () => _previewAndAdd(_results[i]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: IunaPalette.ink3),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: IunaText.body.copyWith(color: IunaPalette.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.hit, required this.onTap});
  final JmdictHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final headline = hit.senses.isEmpty ? '' : hit.senses.first.gloss;
    final showKana = hit.kanji != hit.kana;
    return Material(
      color: const Color(0xB3FFFDF6),
      borderRadius: BorderRadius.circular(IunaRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(IunaRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            hit.kanji,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: IunaPalette.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showKana) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              hit.kana,
                              style: IunaText.bodySmall.copyWith(
                                color: IunaPalette.ink2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        headline,
                        style: IunaText.bodySmall.copyWith(
                          color: IunaPalette.ink2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RarityChip(rarity: hit.rarity, size: RarityChipSize.compact),
            ],
          ),
        ),
      ),
    );
  }
}

/// A deck card found by its meaning; its own screen offers the wishlist.
class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.entry, required this.onTap});
  final CollectionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = entry.card;
    return Material(
      color: const Color(0xB3FFFDF6),
      borderRadius: BorderRadius.circular(IunaRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(IunaRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            card.kanji,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: IunaPalette.ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (card.kanji != card.kana) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              card.kana,
                              style: IunaText.bodySmall.copyWith(
                                color: IunaPalette.ink2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.meaning,
                      style: IunaText.bodySmall.copyWith(
                        color: IunaPalette.ink2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.isOwned) ...[
                      const SizedBox(height: 4),
                      const CardStatusChip(status: CardLookupStatus.owned),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RarityChip(rarity: card.rarity, size: RarityChipSize.compact),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.hit, required this.lookup});
  final JmdictHit hit;
  final CardLookup lookup;

  @override
  Widget build(BuildContext context) {
    final showKana = hit.kanji != hit.kana;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.kanji,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: IunaPalette.ink,
                        ),
                      ),
                      if (showKana)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            hit.kana,
                            style: IunaText.bodyLarge.copyWith(
                              color: IunaPalette.ink2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                RarityChip(rarity: hit.rarity),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (hit.jlptLevel != null)
                  MetaChip(label: 'JLPT N${hit.jlptLevel}'),
                CardStatusChip(status: lookup.status),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    JmdictSenseList(hit.senses),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _PreviewActions(status: lookup.status),
          ],
        ),
      ),
    );
  }
}

class _PreviewActions extends StatelessWidget {
  const _PreviewActions({required this.status});
  final CardLookupStatus status;

  @override
  Widget build(BuildContext context) {
    void pop(_SheetAction action) => Navigator.of(context).pop(action);
    final (String, _SheetAction)? primary = switch (status) {
      CardLookupStatus.notFound ||
      CardLookupStatus.available => ('Add to wishlist', _SheetAction.promote),
      // The status chip above already says it is wished for.
      CardLookupStatus.wishlisted => null,
      CardLookupStatus.owned => ('Open card', _SheetAction.openCard),
    };
    final dismiss = IunaGhostButton(
      label: primary == null || status == CardLookupStatus.owned ? 'Close' : 'Cancel',
      onTap: () => pop(_SheetAction.cancel),
    );
    if (primary == null) return dismiss;
    return Row(
      children: [
        Expanded(child: dismiss),
        const SizedBox(width: 12),
        Expanded(
          child: IunaCtaButton(
            label: primary.$1,
            onTap: () => pop(primary.$2),
          ),
        ),
      ],
    );
  }
}
