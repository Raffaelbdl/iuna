import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/jmdict_lookup.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/hex_bg.dart';
import '../widgets/search_field.dart';
import '../widgets/sense_row.dart';
import '../widgets/vocab_card.dart';
import 'card_detail_screen.dart';

enum _SheetAction { cancel, promote, openCard }

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
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await JmdictLookup.instance.search(q, limit: 50);
    if (!mounted || _query.trim() != q) return;
    setState(() {
      _results = hits;
      _searching = false;
    });
  }

  Future<void> _previewAndAdd(JmdictHit hit) async {
    final lookup = await _repo.lookupByHeadword(hit.kanji, hit.kana);
    if (!mounted) return;

    final action = await showModalBottomSheet<_SheetAction>(
      context: context,
      backgroundColor: IunaPalette.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _PreviewSheet(hit: hit, lookup: lookup),
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
        final result = await _repo.promoteFromJmdict(hit);
        if (!mounted) return;
        final msg = result.wasNew
            ? '${hit.kanji} added — keep an eye on your next pack.'
            : '${hit.kanji} bookmarked — it should turn up soon.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: IunaPalette.pawBrown,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          const Text(
            'Add card',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: IunaPalette.ink,
            ),
          ),
        ],
      ),
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
            'Type a kanji or kana headword to search '
            'the JMdict dictionary.',
      );
    }
    if (_searching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
              style: const TextStyle(color: IunaPalette.ink2, fontSize: 14),
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
                              style: const TextStyle(
                                fontSize: 13,
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
                        style: const TextStyle(
                          fontSize: 13,
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: IunaPalette.ink3.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
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
                            style: const TextStyle(
                              fontSize: 16,
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
                  _MetaChip(label: 'JLPT N${hit.jlptLevel}'),
                _StatusChip(status: lookup.status),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < hit.senses.length; i++)
                      SenseRow(
                        ordinal: i + 1,
                        gloss: hit.senses[i].gloss,
                        pos: hit.senses[i].pos,
                        definition: hit.senses[i].def,
                        showDivider: i > 0,
                      ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: IunaPalette.ink3.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: IunaPalette.ink2,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CardLookupStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CardLookupStatus.notFound => ('New card', IunaPalette.pawBrown),
      CardLookupStatus.available => ('Available', IunaPalette.pawBrown),
      CardLookupStatus.wishlisted => ('On wishlist', IunaPalette.ink2),
      CardLookupStatus.owned => ('In collection', IunaPalette.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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
    switch (status) {
      case CardLookupStatus.notFound:
      case CardLookupStatus.available:
        final label = status == CardLookupStatus.notFound
            ? 'Add to deck'
            : 'Bookmark for boosters';
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_SheetAction.cancel),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_SheetAction.promote),
                child: Text(label),
              ),
            ),
          ],
        );
      case CardLookupStatus.wishlisted:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_SheetAction.cancel),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: null,
                child: const Text('Already wishlisted'),
              ),
            ),
          ],
        );
      case CardLookupStatus.owned:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(_SheetAction.cancel),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(_SheetAction.openCard),
                child: const Text('Open card'),
              ),
            ),
          ],
        );
    }
  }
}
