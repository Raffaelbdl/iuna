import 'package:flutter/material.dart';

import '../db/database.dart';
import '../db/repository.dart';
import '../theme/iuna_theme.dart';
import '../widgets/section_header.dart';
import 'pack_intro_screen.dart';
import 'review_done_screen.dart';
import 'review_screen.dart';

/// A screen of the Today flow (pack, reveal, review, recap), named so
/// the nav can find its way back to it.
MaterialPageRoute<T> todayRoute<T>(WidgetBuilder builder) =>
    MaterialPageRoute<T>(
      builder: builder,
      settings: const RouteSettings(name: _today),
    );

const _today = 'today';

bool isTodayRoute(Route<dynamic> route) => route.settings.name == _today;

/// A Today-flow top bar's title: [label] under a TODAY eyebrow (with
/// [detail] beside it), since the flow's screens hide the nav that
/// would say where you are.
class TodayBarTitle extends StatelessWidget {
  const TodayBarTitle(this.label, {super.key, this.detail});

  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Capped: the bar only grows so far, and the label matters more.
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.4,
          child: IunaEyebrow(detail == null ? 'Today' : 'Today · $detail'),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: IunaText.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IunaPalette.ink2,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

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
  await navigator.push(todayRoute<void>((_) => screen));
}
