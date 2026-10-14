import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import 'pack_intro_screen.dart';
import 'review_done_screen.dart';
import 'review_screen.dart';

/// The Today tab: open a waiting booster, else review what is due, else
/// show today's tally. Completes when the pushed screen is popped, or at
/// once when there is nothing to do.
Future<void> openTodayFlow(BuildContext context, AppDatabase db) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = IunaRepository(db);

  final Widget screen;
  if (await repo.remainingBoostersToday() > 0) {
    screen = PackIntroScreen(db: db);
  } else if (await repo.dueCountToday() > 0) {
    screen = ReviewScreen(db: db);
  } else if ((await repo.todayStats()).total == 0) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nothing to review yet — come back later.')),
    );
    return;
  } else {
    screen = ReviewDoneScreen(db: db, correct: 0, total: 0);
  }
  await navigator.push(MaterialPageRoute(builder: (_) => screen));
}
