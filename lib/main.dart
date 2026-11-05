import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';

import 'db/database.dart';
import 'db/example_english.dart';
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
    // Best effort, off the startup path: examples read fine without it.
    backfillExampleEnglish(_db).catchError((Object _) {});
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
      // differ across regions). The app speaks English, though, so the
      // framework's own strings (Copy/Paste, tooltips, screen-reader
      // labels) stay English under that locale.
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP'), Locale('en', 'US')],
      localizationsDelegates: const [
        _EnglishUnder<MaterialLocalizations>(DefaultMaterialLocalizations.load),
        _EnglishUnder<CupertinoLocalizations>(
          DefaultCupertinoLocalizations.load,
        ),
        _EnglishUnder<WidgetsLocalizations>(DefaultWidgetsLocalizations.load),
      ],
      home: HomeScreen(db: _db),
    );
  }
}

/// The framework's US English strings, whatever the locale: the app
/// keeps ja-JP for glyph selection only.
class _EnglishUnder<T> extends LocalizationsDelegate<T> {
  const _EnglishUnder(this._load);

  final Future<T> Function(Locale locale) _load;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _load(locale);

  @override
  bool shouldReload(_EnglishUnder<T> old) => false;
}
