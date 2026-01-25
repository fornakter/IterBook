import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/book_service.dart';
import 'services/reading_preferences_service.dart';
import 'screens/menu_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final BookService _bookService = BookService();
  final ReadingPreferencesService _preferencesService = ReadingPreferencesService();

  @override
  void initState() {
    super.initState();
    _preferencesService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IterBook',
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('pl')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: MenuScreen(
        bookService: _bookService,
        preferencesService: _preferencesService,
      ),
    );
  }
}

