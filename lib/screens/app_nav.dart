import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../learn/learn_settings.dart';
import '../learn/screens/learn_screen.dart';
import '../widgets/iuna_bottom_nav.dart';
import 'collection_screen.dart';
import 'today_flow.dart';

/// The bottom nav wired to the app's tabs. Every screen that shows it goes
/// through here, so adding a tab is one edit.
///
/// Home is the root and every other tab sits directly on it: from Home a
/// tab is pushed (and [onReturn] refreshes Home when it pops); from any
/// other screen it replaces that screen, so bouncing between tabs never
/// stacks them up.
/// What Today holds for [db]: the new cards of an unopened pack plus
/// the reviews due, null until first counted. One per database, shared
/// by every nav on it.
final _todayCounts = Expando<ValueNotifier<int?>>();

ValueNotifier<int?> _todayCount(AppDatabase db) =>
    _todayCounts[db] ??= ValueNotifier(null);

/// Sets the Today badge from counts a screen already fetched.
void publishTodayCount(AppDatabase db, int count) =>
    _todayCount(db).value = count;

/// Recounts the Today badge, after anything that opens a pack or
/// reviews a card.
Future<void> refreshTodayCount(AppDatabase db) async {
  final repo = IunaRepository(db);
  try {
    final (preview, due) = await (
      repo.boosterPreview(),
      repo.dueCountToday(),
    ).wait;
    publishTodayCount(db, preview.newCards + due);
  } catch (e) {
    // A badge is not worth an error; it keeps its last count.
    debugPrint('Today badge failed to count: $e');
  }
}

class AppBottomNav extends StatefulWidget {
  const AppBottomNav({
    super.key,
    required this.db,
    required this.active,
    this.atTabRoot = true,
    this.onReturn,
  });

  final AppDatabase db;
  final IunaNavTab active;

  /// False on a screen that highlights a tab without being it (card
  /// detail shows Collection): tapping that tab then goes to it.
  final bool atTabRoot;

  /// Runs when a flow or tab pushed from here comes back.
  final Future<void> Function()? onReturn;

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  AppDatabase get db => widget.db;
  IunaNavTab get active => widget.active;

  @override
  void initState() {
    super.initState();
    // A remount (the ask bar's keyboard, a reparent) keeps the count.
    if (_todayCount(db).value == null) refreshTodayCount(db);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LearnSettings.instance.available,
      builder: (context, showLearn, _) => ValueListenableBuilder<int?>(
        valueListenable: _todayCount(db),
        builder: (context, todayCount, _) => IunaBottomNav(
          active: active,
          showLearn: showLearn,
          todayCount: todayCount ?? 0,
          onTap: (tab) => _go(context, tab),
        ),
      ),
    );
  }

  Future<void> _go(BuildContext context, IunaNavTab tab) async {
    if (tab == active && widget.atTabRoot) return;
    final navigator = Navigator.of(context);
    switch (tab) {
      case IunaNavTab.home:
        navigator.popUntil((r) => r.isFirst);
        return;
      case IunaNavTab.today:
        // Off a screen the Today flow opened (a card from the recap):
        // back to that flow rather than a second one over it.
        if (!widget.atTabRoot) {
          var found = false;
          navigator.popUntil((r) {
            found = isTodayRoute(r);
            return found || r.isFirst;
          });
          if (found) return;
        }
        await openTodayFlow(context, db);
      case IunaNavTab.collection || IunaNavTab.learn:
        final route = MaterialPageRoute<void>(
          builder: (_) => tab == IunaNavTab.collection
              ? CollectionScreen(db: db)
              : LearnScreen(db: db),
        );
        if (active != IunaNavTab.home) {
          unawaited(navigator.pushReplacement(route));
          return;
        }
        await navigator.push(route);
    }
    // Home's refresh publishes the count itself.
    final onReturn = widget.onReturn;
    await [
      if (active != IunaNavTab.home || onReturn == null) refreshTodayCount(db),
      if (onReturn != null) onReturn(),
    ].wait;
  }
}
