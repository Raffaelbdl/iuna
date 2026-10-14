import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/screens/settings_screen.dart';

import 'helpers/fake_path_provider.dart';

void main() {
  late AppDatabase db;
  late IunaRepository repo;

  setUp(() {
    useTempDocumentsDir('iuna_settings_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(db);
    LearnSettings.instance = LearnSettings(MemorySecretStore());
  });

  tearDown(() async {
    await db.close();
    LearnSettings.instance = LearnSettings(const KeystoreSecretStore());
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(db: db)));
    await tester.pumpAndSettle();
  }

  testWidgets('credits every bundled data source', (tester) async {
    await pumpSettings(tester);
    for (final title in [
      'JMdict',
      'JLPT vocabulary lists',
      'Example sentences',
      'Word frequency',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(
      find.textContaining('Creative Commons Attribution-ShareAlike'),
      findsWidgets,
    );
    expect(find.textContaining('Attribution 2.0 France'), findsOneWidget);
    expect(find.textContaining('Attribution 2.5'), findsOneWidget);
  });

  testWidgets('booster-pack stepper persists to meta', (tester) async {
    await pumpSettings(tester);

    expect(await repo.getBoostersPerDay(), kDefaultBoostersPerDay);

    // Multiple steppers on the screen now (boosters + review-time cap).
    // Scope to the booster row so the +/− icons are unambiguous.
    final boosterRow = find.ancestor(
      of: find.text('Booster packs per day'),
      matching: find.byType(ListTile),
    );
    final inc = find.descendant(
      of: boosterRow,
      matching: find.byIcon(Icons.add_circle_outline_rounded),
    );
    final dec = find.descendant(
      of: boosterRow,
      matching: find.byIcon(Icons.remove_circle_outline_rounded),
    );

    await tester.tap(inc);
    await tester.pump();
    await tester.tap(inc);
    await tester.pump();
    expect(await repo.getBoostersPerDay(), kDefaultBoostersPerDay + 2);

    await tester.tap(dec);
    await tester.pump();
    expect(await repo.getBoostersPerDay(), kDefaultBoostersPerDay + 1);
  });

  testWidgets('reset-hour dropdown persists to meta', (tester) async {
    await pumpSettings(tester);

    expect(await repo.getResetHour(), kDefaultResetHour);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    // intl's DateFormat.j() uses a NARROW NO-BREAK SPACE (U+202F)
    // between digit and AM/PM in en_US, so we have to ask intl for
    // the exact label rather than typing "4 AM" literally.
    final label = DateFormat.j().format(DateTime(2000, 1, 1, 4));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();

    expect(await repo.getResetHour(), 4);
  });
}
