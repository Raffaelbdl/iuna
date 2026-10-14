import 'dart:async';

import 'package:flutter/material.dart';

import '../db/database.dart';
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
class AppBottomNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LearnSettings.instance.available,
      builder: (context, showLearn, _) => IunaBottomNav(
        active: active,
        showLearn: showLearn,
        onTap: (tab) => _go(context, tab),
      ),
    );
  }

  Future<void> _go(BuildContext context, IunaNavTab tab) async {
    if (tab == active && atTabRoot) return;
    final navigator = Navigator.of(context);
    switch (tab) {
      case IunaNavTab.home:
        navigator.popUntil((r) => r.isFirst);
        return;
      case IunaNavTab.today:
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
    await onReturn?.call();
  }
}
