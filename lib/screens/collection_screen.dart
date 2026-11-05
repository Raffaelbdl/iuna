import 'dart:async';

import 'package:flutter/material.dart';

import '../core/japanese_text.dart';
import '../db/database.dart';
import '../db/repository.dart';
import '../services/dict_download.dart';
import '../theme/iuna_theme.dart';
import '../widgets/cta_button.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/notice.dart';
import '../widgets/search_field.dart';
import '../widgets/tab_header.dart';
import '../widgets/tappable.dart';
import '../widgets/vocab_card.dart';
import 'add_card_screen.dart';
import 'app_nav.dart';
import 'card_detail_screen.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.db,
    this.initialWishedOnly = false,
  });

  final AppDatabase db;

  /// Opens on the Wishlist filter (from Home's wishlist row).
  final bool initialWishedOnly;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final IunaRepository _repo = IunaRepository(widget.db);
  late final TextEditingController _queryCtrl = TextEditingController();

  Set<Rarity> _selected = const {};
  String _query = '';
  bool _showMissing = false;
  late bool _wishedOnly = widget.initialWishedOnly;
  bool _suspendedOnly = false;
  bool _shuffled = false;

  bool _loading = true;
  bool _failed = false;
  CollectionStats? _stats;
  int _wishCount = 0;
  List<CollectionEntry> _entries = const [];
  bool _dictInstalled = false;

  Timer? _debounce;

  /// Bumped per entries query; a reply for an older one is dropped so a
  /// slow search can't overwrite a newer one.
  int _entriesGen = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<List<CollectionEntry>> _queryEntries() => _repo.ownedCards(
    query: _query,
    rarities: _selected,
    includeUnowned: _showMissing,
    wishedOnly: _wishedOnly,
    suspendedOnly: _suspendedOnly,
  );

  Future<List<CollectionEntry>> _queryOrdered() async {
    final entries = await _queryEntries();
    return _shuffled ? (List.of(entries)..shuffle()) : entries;
  }

  Future<void> _reloadEntries() async {
    final gen = ++_entriesGen;
    final entries = await _queryOrdered();
    if (!mounted || gen != _entriesGen) return;
    setState(() => _entries = entries);
  }

  Future<void> _probeDict() async {
    final installed = await DictDownload.isInstalled();
    if (mounted && installed != _dictInstalled) {
      setState(() => _dictInstalled = installed);
    }
  }

  Future<void> _refresh() async {
    final gen = ++_entriesGen;
    unawaited(_probeDict());
    try {
      final (stats, wishCount, entries) = await (
        _repo.collectionStats(),
        _repo.wishedCount(),
        _queryOrdered(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _wishCount = wishCount;
        if (gen == _entriesGen) _entries = entries;
        _loading = false;
        _failed = false;
      });
    } catch (e, s) {
      logLoadError('Collection', e, s);
      if (mounted && _stats == null) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  /// The "+" in the header.
  Future<void> _onAdd() async {
    await openAddToWishlist(
      context,
      widget.db,
      initialQuery: _query.trim().isEmpty ? null : _query.trim(),
      dictInstalled: _dictInstalled,
    );
    if (!mounted) return;
    await _probeDict();
    await _refresh();
  }

  Future<void> _openAddCard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddCardScreen(
          db: widget.db,
          initialQuery: _query.trim().isEmpty ? null : _query.trim(),
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _reloadEntries);
  }

  Future<void> _toggleRarity(Rarity r) async {
    final next = Set<Rarity>.of(_selected);
    if (!next.add(r)) next.remove(r);
    setState(() => _selected = next);
    await _reloadEntries();
  }

  Future<void> _clearRarityFilter() async {
    setState(() => _selected = const {});
    await _reloadEntries();
  }

  Future<void> _toggleShowMissing() async {
    setState(() => _showMissing = !_showMissing);
    await _reloadEntries();
  }

  Future<void> _toggleWishedOnly() async {
    setState(() => _wishedOnly = !_wishedOnly);
    await _reloadEntries();
  }

  Future<void> _toggleSuspendedOnly() async {
    setState(() => _suspendedOnly = !_suspendedOnly);
    await _reloadEntries();
  }

  /// Shuffled until tapped again, which restores the usual order.
  Future<void> _toggleShuffle() async {
    setState(() => _shuffled = !_shuffled);
    await _reloadEntries();
  }

  bool get _filtered =>
      _selected.isNotEmpty ||
      _query.isNotEmpty ||
      _wishedOnly ||
      _suspendedOnly;

  Future<void> _clearFilters() async {
    _queryCtrl.clear();
    setState(() {
      _query = '';
      _selected = const {};
      _wishedOnly = false;
      _suspendedOnly = false;
    });
    await _reloadEntries();
  }

  Future<void> _openDetail(int cardId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardDetailScreen(
          db: widget.db,
          cardId: cardId,
          from: IunaNavTab.collection,
        ),
      ),
    );
    if (!mounted) return;
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IunaPalette.bg,
      body: DecoratedBox(
        decoration: iunaPageBackground(),
        child: Stack(
          children: [
            const Positioned.fill(child: HexBg(seed: 5, calmTop: 0.4)),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _failed
                  ? LoadErrorNotice(
                      onRetry: () {
                        setState(() {
                          _loading = true;
                          _failed = false;
                        });
                        _refresh();
                      },
                    )
                  : _buildBody(),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(child: IunaNavFade()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(
                db: widget.db,
                active: IunaNavTab.collection,
                onReturn: _refresh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final stats = _stats!;
    // The header and search stay; the filters and progress scroll away
    // with the grid, so large text still leaves room for cards.
    return Column(
      children: [
        IunaTabHeader(
          'Collection',
          actions: [
            IunaIconButton(
              icon: Icons.bookmark_add_outlined,
              tooltip: 'Add to wishlist',
              onTap: _onAdd,
            ),
            IunaIconButton(
              icon: _shuffled
                  ? Icons.shuffle_on_rounded
                  : Icons.shuffle_rounded,
              tooltip: 'Shuffle',
              selected: _shuffled,
              tint: _shuffled ? IunaPalette.honeyInk : null,
              onTap: _toggleShuffle,
            ),
          ],
        ),
        IunaSearchField(
          controller: _queryCtrl,
          hint: 'Search kanji, kana or meaning…',
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: 2),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _RarityFilters(
                  selected: _selected,
                  onToggle: _toggleRarity,
                  onClear: _clearRarityFilter,
                  wishedOnly: _wishedOnly,
                  wishCount: _wishCount,
                  onToggleWishedOnly: _toggleWishedOnly,
                  suspendedOnly: _suspendedOnly,
                  onToggleSuspendedOnly: _toggleSuspendedOnly,
                  showMissing: _showMissing,
                  onToggleShowMissing: _toggleShowMissing,
                ),
              ),
              SliverToBoxAdapter(child: _ProgressStrip(stats: stats)),
              if (_entries.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 90),
                    child: _query.trim().isNotEmpty &&
                            !_showMissing &&
                            !_wishedOnly &&
                            !_suspendedOnly
                        ? _NotCollected(
                            onShowMissing: _toggleShowMissing,
                            // The dictionary looks up Japanese only.
                            onSearchDictionary:
                                _dictInstalled && japaneseRun.hasMatch(_query)
                                ? _openAddCard
                                : null,
                            onClearSearch: _clearFilters,
                          )
                        : _EmptyState(
                            narrowed:
                                _selected.isNotEmpty || _query.isNotEmpty,
                            wishedOnly: _wishedOnly,
                            suspendedOnly: _suspendedOnly,
                            showMissing: _showMissing,
                            onClearFilters: _filtered ? _clearFilters : null,
                          ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 3 / 4,
                        ),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final entry = _entries[i];
                      return _HexTile(
                        entry: entry,
                        onTap: () => _openDetail(entry.card.id),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RarityFilters extends StatelessWidget {
  const _RarityFilters({
    required this.selected,
    required this.onToggle,
    required this.onClear,
    required this.wishedOnly,
    required this.wishCount,
    required this.onToggleWishedOnly,
    required this.suspendedOnly,
    required this.onToggleSuspendedOnly,
    required this.showMissing,
    required this.onToggleShowMissing,
  });

  final Set<Rarity> selected;
  final ValueChanged<Rarity> onToggle;
  final VoidCallback onClear;
  final bool wishedOnly;
  final int wishCount;
  final VoidCallback onToggleWishedOnly;
  final bool suspendedOnly;
  final VoidCallback onToggleSuspendedOnly;
  final bool showMissing;
  final VoidCallback onToggleShowMissing;

  @override
  Widget build(BuildContext context) {
    // Rows that wrap, so no filter hides off-screen: rarity, then
    // which cards.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              _Chip(label: 'All', active: selected.isEmpty, onTap: onClear),
              for (final r in Rarity.values)
                Tooltip(
                  message: rarityName(r),
                  excludeFromSemantics: true,
                  child: _Chip(
                    label: rarityCode(r),
                    semanticLabel: rarityName(r),
                    rarity: r,
                    active: selected.contains(r),
                    onTap: () => onToggle(r),
                  ),
                ),
            ],
          ),
          Wrap(
            children: [
              _Chip(
                label: wishCount > 0 ? 'Wishlist · $wishCount' : 'Wishlist',
                active: wishedOnly,
                onTap: onToggleWishedOnly,
              ),
              _Chip(
                label: 'Suspended',
                active: suspendedOnly,
                onTap: onToggleSuspendedOnly,
              ),
              _Chip(
                label: 'Show missing',
                active: showMissing,
                onTap: onToggleShowMissing,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A filter toggle: a 34 px pill on a 48 px tap target. Active chips
/// carry a check so the state doesn't rest on colour alone.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.rarity,
    this.semanticLabel,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Rarity? rarity;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rarity = this.rarity;
    Color bg;
    Color fg;
    Color border = IunaPalette.hairline;
    double borderWidth = 0.5;
    // A picked tier keeps its colour, deeper and outlined in its ink,
    // so several picked tiers still read apart.
    final honey = active && rarity == null;
    if (active && rarity != null) {
      bg = rarityColor(rarity);
      fg = rarityInk(rarity);
      border = rarityInk(rarity);
      borderWidth = 1.5;
    } else if (active) {
      bg = IunaPalette.honey;
      fg = IunaPalette.heroInk;
      border = IunaPalette.honeyInk.withValues(alpha: 0.2);
    } else if (rarity != null) {
      bg = rarityFill(rarity);
      fg = rarityInk(rarity);
    } else {
      bg = IunaPalette.chipBg;
      fg = IunaPalette.ink2;
    }
    return Tappable(
      onTap: onTap,
      selected: active,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // 42 + the 3 px either side: a 48 px target for a one-letter
          // tier.
          constraints: const BoxConstraints(minHeight: 34, minWidth: 42),
          // Less padding under a thicker border, so a pick doesn't grow.
          padding: EdgeInsets.symmetric(
            horizontal: 12.5 - borderWidth,
            vertical: 7.5 - borderWidth,
          ),
          decoration: BoxDecoration(
            gradient: honey
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [IunaPalette.heroTop, IunaPalette.honey],
                  )
                : null,
            color: honey ? null : bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: borderWidth),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Icon(Icons.check_rounded, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: IunaText.chip.copyWith(
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of the deck is collected: one line and a bar, opening on
/// tap to the per-tier counts.
class _ProgressStrip extends StatefulWidget {
  const _ProgressStrip({required this.stats});
  final CollectionStats stats;

  @override
  State<_ProgressStrip> createState() => _ProgressStripState();
}

class _ProgressStripState extends State<_ProgressStrip> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final pct = stats.total == 0 ? 0.0 : stats.owned / stats.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        decoration: paperPanelDecoration(
          borderRadius: BorderRadius.circular(IunaRadii.md),
        ),
        child: Tappable(
          onTap: () => setState(() => _open = !_open),
          expanded: _open,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text:
                              '${_thousands(stats.owned)} / '
                              '${_thousands(stats.total)} '
                              'collected',
                          children: [
                            TextSpan(
                              text: ' · ${_percent(pct)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: IunaPalette.ink3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        style: IunaText.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: IunaPalette.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: IunaPalette.ink3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 8,
                    child: Row(
                      children: [
                        // A tier with no cards gets no segment: a zero
                        // flex would leave it unbounded.
                        for (final r in Rarity.values)
                          if ((stats.totalByRarity[r] ?? 0) > 0)
                            Expanded(
                              flex: stats.totalByRarity[r]!,
                              child: _RaritySegment(
                                owned: stats.ownedByRarity[r] ?? 0,
                                total: stats.totalByRarity[r] ?? 0,
                                color: rarityColor(r),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: !_open
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              for (final r in Rarity.values)
                                _LegendChip(
                                  rarity: r,
                                  owned: stats.ownedByRarity[r] ?? 0,
                                  total: stats.totalByRarity[r] ?? 0,
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _percent(double pct) {
  if (pct > 0 && pct < 0.01) return '<1%';
  return '${(pct * 100).floor()}%';
}

String _thousands(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

class _RaritySegment extends StatelessWidget {
  const _RaritySegment({
    required this.owned,
    required this.total,
    required this.color,
  });
  final int owned;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : owned / total;
    return Container(
      color: IunaPalette.chipBg,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(color: color),
      ),
    );
  }
}

/// One tier in the progress legend: its code as the cards print it,
/// its name, and how many of it are collected.
class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.rarity,
    required this.owned,
    required this.total,
  });
  final Rarity rarity;
  final int owned;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: rarityColor(rarity),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          rarityCode(rarity),
          style: IunaText.chip.copyWith(
            fontWeight: FontWeight.w800,
            color: IunaPalette.ink2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          rarityName(rarity),
          style: IunaText.caption.copyWith(color: IunaPalette.ink2),
        ),
        const SizedBox(width: 4),
        Text(
          '$owned/$total',
          style: IunaText.caption.copyWith(
            color: IunaPalette.ink3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _HexTile extends StatelessWidget {
  const _HexTile({required this.entry, required this.onTap});

  final CollectionEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = entry.card;
    final owned = entry.isOwned;
    final tint = rarityFill(card.rarity);
    final suspended = owned && entry.userCard?.suspended == true;
    final level = owned ? entry.userCard?.level ?? 0 : 0;
    // A missing card's kanji and meaning are hidden on screen, so a
    // screen reader must not read them out either.
    final String label;
    if (!owned) {
      label = 'Missing ${rarityName(card.rarity)} card';
    } else {
      label = [
        card.kanji,
        if (card.kana != card.kanji) card.kana,
        card.meaning,
        '${rarityName(card.rarity)} card',
        if (suspended) 'suspended' else if (level > 0) 'memory level $level',
      ].join(', ');
    }
    return Tappable(
      onTap: onTap,
      label: label,
      child: ExcludeSemantics(
        child: _tile(card, owned: owned, tint: tint, suspended: suspended),
      ),
    );
  }

  Widget _tile(
    CardRow card, {
    required bool owned,
    required Color tint,
    required bool suspended,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-0.3, -1),
          end: const Alignment(0.3, 1),
          colors: [IunaPalette.paper, tint],
        ),
        borderRadius: BorderRadius.circular(IunaRadii.md),
        boxShadow: panelShadow(),
        border: Border.all(color: IunaPalette.hairline, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(IunaRadii.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Centered kanji — pinned to the visual center of the tile
            // so its position is stable regardless of caption length.
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Hero(
                  tag: 'card-kanji-${card.id}',
                  flightShuttleBuilder: _kanjiFlightShuttle,
                  child: Material(
                    color: Colors.transparent,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.kanji,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: IunaPalette.ink,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Caption strip pinned to the bottom of the tile.
            Positioned(
              left: 10,
              right: 10,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.kana,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IunaText.caption.copyWith(
                      color: IunaPalette.ink3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.meaning,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IunaText.caption.copyWith(
                      fontWeight: FontWeight.w500,
                      color: IunaPalette.ink2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!owned)
              // Heavy paper overlay for "missing" tiles. Sits above
              // the kanji + caption so the underlying content reads
              // as a faint silhouette, with a centered '？'. Corner
              // rarity / level pill render on top of the overlay.
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: IunaPalette.paper.withValues(alpha: 0.95),
                      ),
                      const Center(
                        child: Text(
                          '？',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: IunaPalette.inkMute,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (suspended)
              // Whole-tile wash so a suspended card reads as inactive
              // at a glance, without hiding the kanji the way the
              // "missing" overlay does.
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: IunaPalette.paperGlass),
                ),
              ),
            // One row, so a long rarity chip shrinks rather than runs
            // under the badge at large text.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: 1,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Opacity(
                          opacity: suspended ? 0.5 : 1,
                          child: RarityChip(
                            rarity: card.rarity,
                            size: RarityChipSize.tiny,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (suspended) ...[
                    const SizedBox(width: 6),
                    const _SuspendedBadge(),
                  ] else if (owned && (entry.userCard?.level ?? 0) > 0) ...[
                    const SizedBox(width: 6),
                    _LevelPill(level: entry.userCard!.level),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuspendedBadge extends StatelessWidget {
  const _SuspendedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: IunaPalette.ink.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_rounded, size: 12, color: IunaPalette.honeyPale),
          SizedBox(width: 3),
          Text(
            'Suspended',
            style: IunaText.chip.copyWith(
              fontWeight: FontWeight.w700,
              color: IunaPalette.honeyPale,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _kanjiFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return Material(color: Colors.transparent, child: toHeroContext.widget);
}

/// The card's memory level, quiet beside the rarity chip: the same
/// "Lv" card detail shows.
class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: IunaPalette.paper.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IunaPalette.outline, width: 0.5),
      ),
      child: Text(
        memoryLevelLabel(level),
        style: IunaText.chip.copyWith(color: IunaPalette.ink2),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.narrowed,
    required this.wishedOnly,
    required this.suspendedOnly,
    required this.showMissing,
    this.onClearFilters,
  });

  /// A search or a rarity filter is on.
  final bool narrowed;
  final bool wishedOnly;
  final bool suspendedOnly;
  final bool showMissing;

  /// Null when no filter narrows the grid.
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final String message;
    final IconData icon;
    if (narrowed) {
      icon = Icons.search_off_rounded;
      message = 'No matching cards.';
    } else if (wishedOnly) {
      icon = Icons.bookmark_outline_rounded;
      message =
          'Your wishlist is empty. Tap the bookmark on a card to add '
          'it — it shows up in a pack soon.';
    } else if (suspendedOnly) {
      icon = Icons.pause_circle_outline_rounded;
      message = 'No suspended cards.';
    } else if (showMissing) {
      icon = Icons.search_off_rounded;
      message = 'No matching cards.';
    } else {
      icon = Icons.style_rounded;
      message = 'No cards yet — open a pack to start your collection.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: IunaPalette.inkMute),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: IunaText.body.copyWith(color: IunaPalette.ink3),
            ),
            if (onClearFilters != null) ...[
              const SizedBox(height: 16),
              IunaGhostButton(
                label: 'Clear filters',
                leadingIcon: Icons.filter_alt_off_rounded,
                shrinkWrap: true,
                onTap: onClearFilters,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A search with no match among the cards collected: look among all
/// cards, or in the dictionary, rather than stop at "no match".
class _NotCollected extends StatelessWidget {
  const _NotCollected({
    required this.onShowMissing,
    required this.onSearchDictionary,
    required this.onClearSearch,
  });

  final VoidCallback onShowMissing;

  /// Null without the dictionary.
  final VoidCallback? onSearchDictionary;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final dictionary = onSearchDictionary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'None in your collection.',
              textAlign: TextAlign.center,
              style: IunaText.body.copyWith(color: IunaPalette.ink3),
            ),
            const SizedBox(height: 16),
            IunaGhostButton(
              label: 'Show missing',
              leadingIcon: Icons.help_outline_rounded,
              shrinkWrap: true,
              onTap: onShowMissing,
            ),
            if (dictionary != null) ...[
              const SizedBox(height: 10),
              IunaGhostButton(
                label: 'Search the dictionary',
                leadingIcon: Icons.menu_book_rounded,
                shrinkWrap: true,
                onTap: dictionary,
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: onClearSearch,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}
