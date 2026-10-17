import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'db/database.dart';
import 'learn/learn_settings.dart';
import 'screens/home_screen.dart';
import 'services/app_update.dart';
import 'theme/iuna_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppUpdate.supported) AppUpdate.clearDownloaded();
  runApp(const IunaApp());
}

class IunaApp extends StatefulWidget {
  const IunaApp({super.key});

  @override
  State<IunaApp> createState() => _IunaAppState();
}

class _IunaAppState extends State<IunaApp> {
  late final AppDatabase _db = AppDatabase();

  @override
  void initState() {
    super.initState();
    LearnSettings.instance.load();
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Iuna',
      debugShowCheckedModeBanner: false,
      theme: buildIunaTheme(),
      // Force ja-JP so Noto Sans CJK resolves Han codepoints to the JP
      // sub-font instead of the Simplified Chinese one (e.g. 直/骨/今
      // differ across regions).
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(db: _db),
    );
  }
}
