import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../services/dict_download.dart';
import '../theme/iuna_theme.dart';
import '../widgets/hex_bg.dart';
import '../widgets/iuna_bottom_nav.dart';
import '../widgets/iuna_icon_button.dart';
import '../widgets/search_field.dart';
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

  bool _loading = true;
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

  Future<void> _reloadEntries() async {
    final gen = ++_entriesGen;
    final entries = await _queryEntries();
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
    final (stats, wishCount, entries) = await (
      _repo.collectionStats(),
      _repo.wishedCount(),
      _queryEntries(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _wishCount = wishCount;
      if (gen == _entriesGen) _entries = entries;
      _loading = false;
    });
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

  Future<void> _shuffle() async {
    final list = List<CollectionEntry>.of(_entries)..shuffle();
    setState(() => _entries = list);
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
            const Positioned.fill(child: HexBg(seed: 5)),
            SafeArea(
              bottom: false,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
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
    return Column(
      children: [
        _TopBar(
          onShuffle: _shuffle,
          onAdd: _dictInstalled ? _openAddCard : null,
        ),
        IunaSearchField(
          controller: _queryCtrl,
          hint: 'Search kanji, kana or meaning…',
          onChanged: _onQueryChanged,
        ),
        const SizedBox(height: 2),
        _RarityFilters(
          selected: _selected,
          onToggle: _toggleRarity,
          onClear: _clearRarityFilter,
          wishedOnly: _wishedOnly,
          wishCount: _wishCount,
          onToggleWishedOnly: _toggleWishedOnly,
          suspendedOnly: _suspendedOnly,
          onToggleSuspendedOnly: _toggleSuspendedOnly,
        ),
        _ProgressStrip(
          stats: stats,
          showMissing: _showMissing,
          onToggleShowMissing: _toggleShowMissing,
        ),
        Expanded(
          child: _entries.isEmpty
              ? _EmptyState(
                  narrowed: _selected.isNotEmpty || _query.isNotEmpty,
                  wishedOnly: _wishedOnly,
                  suspendedOnly: _suspendedOnly,
                  showMissing: _showMissing,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
    );
  }
}

/// A tab root, so no back button: the system Back still pops it.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onShuffle, this.onAdd});
  final VoidCallback onShuffle;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 10, 2),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Collection',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: IunaPalette.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (onAdd != null)
            IunaIconButton(
              icon: Icons.add_rounded,
              tooltip: 'Add to wishlist',
              onTap: onAdd!,
            ),
          IunaIconButton(
            icon: Icons.shuffle_rounded,
            tooltip: 'Shuffle',
            onTap: onShuffle,
          ),
        ],
      ),
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
  });

  final Set<Rarity> selected;
  final ValueChanged<Rarity> onToggle;
  final VoidCallback onClear;
  final bool wishedOnly;
  final int wishCount;
  final VoidCallback onToggleWishedOnly;
  final bool suspendedOnly;
  final VoidCallback onToggleSuspendedOnly;

  @override
  Widget build(BuildContext context) {
    // Rows that wrap, so no filter hides off-screen: rarity, then
    // which cards. "Show missing" sits with the collected count.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              _Chip(label: 'All', active: selected.isEmpty, onTap: onClear),
              for (final r in Rarity.values)
                _Chip(
                  label: rarityCode(r),
                  semanticLabel: rarityName(r),
                  rarity: r,
                  active: selected.contains(r),
                  onTap: () => onToggle(r),
                ),
            ],
          ),
          Wrap(
            children: [
              _Chip(
                label: wishCount > 0 ? 'Wishlist · $wishCount' : 'Wishlist',
                icon: Icons.bookmark_rounded,
                active: wishedOnly,
                onTap: onToggleWishedOnly,
              ),
              _Chip(
                label: 'Suspended',
                icon: Icons.pause_circle_outline_rounded,
                active: suspendedOnly,
                onTap: onToggleSuspendedOnly,
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
    this.icon,
    this.rarity,
    this.semanticLabel,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final Rarity? rarity;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border = const Color.fromRGBO(74, 53, 32, 0.06);
    if (active) {
      bg = const Color(0xFFF0B66C);
      fg = IunaPalette.heroInk;
      border = const Color.fromRGBO(120, 70, 20, 0.15);
    } else if (rarity != null) {
      bg = rarityFill(rarity!);
      fg = rarityInk(rarity!);
    } else {
      bg = const Color(0x0F4A3520);
      fg = IunaPalette.ink2;
    }
    final glyph = active ? Icons.check_rounded : icon;
    return Tappable(
      onTap: onTap,
      selected: active,
      label: semanticLabel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 34, minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [IunaPalette.heroTop, Color(0xFFF0B66C)],
                  )
                : null,
            color: active ? null : bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                Icon(glyph, size: 14, color: fg),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({
    required this.stats,
    required this.showMissing,
    required this.onToggleShowMissing,
  });
  final CollectionStats stats;
  final bool showMissing;
  final VoidCallback onToggleShowMissing;

  @override
  Widget build(BuildContext context) {
    final pct = stats.total == 0 ? 0.0 : stats.owned / stats.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 8, 12),
        decoration: paperPanelDecoration(
          borderRadius: BorderRadius.circular(IunaRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text:
                          '${_format(stats.owned)} / ${_format(stats.total)} '
                          'collected',
                      children: [
                        TextSpan(
                          text: ' · ${(pct * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: IunaPalette.ink3,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: IunaPalette.ink,
                    ),
                  ),
                ),
                _Chip(
                  label: 'Show missing',
                  icon: Icons.help_outline_rounded,
                  active: showMissing,
                  onTap: onToggleShowMissing,
                ),
              ],
            ),
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    // A tier with no cards gets no segment: a zero flex
                    // would leave it unbounded.
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
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
          ],
        ),
      ),
    );
  }

  static String _format(int n) {
    final s = n.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }
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
      color: const Color.fromRGBO(74, 53, 32, 0.06),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(color: color),
      ),
    );
  }
}

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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: IunaPalette.ink2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$owned/$total',
          style: const TextStyle(
            fontSize: 12,
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
    return Tappable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.3, -1),
            end: const Alignment(0.3, 1),
            colors: [IunaPalette.paper, tint],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: panelShadow(),
          border: Border.all(
            color: const Color.fromRGBO(74, 53, 32, 0.06),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: IunaPalette.ink3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.meaning,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
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
                        Container(color: const Color(0xF2FFFDF6)),
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
              Positioned(
                top: 8,
                left: 8,
                child: RarityChip(
                  rarity: card.rarity,
                  size: RarityChipSize.tiny,
                ),
              ),
              if (suspended)
                // Whole-tile wash so a suspended card reads as inactive
                // at a glance, without hiding the kanji the way the
                // "missing" overlay does.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(color: const Color(0x66FFFDF6)),
                  ),
                ),
              if (suspended)
                const Positioned(top: 8, right: 8, child: _SuspendedBadge())
              else if (owned && (entry.userCard?.level ?? 0) > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LevelPill(level: entry.userCard!.level),
                ),
            ],
          ),
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
        color: const Color.fromRGBO(74, 53, 32, 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_rounded, size: 12, color: Color(0xFFFFE9A8)),
          SizedBox(width: 3),
          Text(
            'Suspended',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFE9A8),
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

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(74, 53, 32, 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Lv $level',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFE9A8),
          letterSpacing: 0.4,
        ),
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
  });

  /// A search or a rarity filter is on.
  final bool narrowed;
  final bool wishedOnly;
  final bool suspendedOnly;
  final bool showMissing;

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
              style: const TextStyle(fontSize: 14, color: IunaPalette.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
