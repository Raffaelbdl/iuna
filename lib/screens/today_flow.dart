import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import 'pack_intro_screen.dart';
import 'review_done_screen.dart';
import 'review_screen.dart';

/// The Today tab: open a waiting booster, else review what is due, else
/// show today's tally and when the next pack and review come. Completes
/// when the pushed screen is popped.
Future<void> openTodayFlow(BuildContext context, AppDatabase db) async {
  final navigator = Navigator.of(context);
  final repo = IunaRepository(db);

  final Widget screen;
  if ((await repo.boosterPreview()).newCards > 0) {
    screen = PackIntroScreen(db: db);
  } else if (await repo.dueCountToday() > 0) {
    screen = ReviewScreen(db: db);
  } else {
    screen = ReviewDoneScreen(db: db, correct: 0, total: 0);
  }
  await navigator.push(MaterialPageRoute(builder: (_) => screen));
}
