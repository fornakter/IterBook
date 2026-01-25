# Internationalization (i18n) - IterBook

## Struktura

```
lib/l10n/
├── app_en.arb          # Tłumaczenia angielskie (English)
├── app_pl.arb          # Tłumaczenia polskie (Polish)
└── app_localizations.dart  # Wygenerowany plik (nie edytować!)
```

## Jak używać w kodzie

### 1. Import w widoku:
```dart
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
```

### 2. Użycie tłumaczeń:
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;

  return Text(l10n.welcome); // Wyświetli "Witaj w IterBook" lub "Welcome to IterBook"
}
```

### 3. Zmiana języka:
```dart
// Poprzez LocaleService
localeService.changeLanguage('pl'); // Polski
localeService.changeLanguage('en'); // Angielski
```

## Dodawanie nowych tłumaczeń

### Krok 1: Dodaj klucz do `app_en.arb`
```json
{
  "newKey": "New text in English",
  "@newKey": {
    "description": "Description for developers"
  }
}
```

### Krok 2: Dodaj tłumaczenie do `app_pl.arb`
```json
{
  "newKey": "Nowy tekst po polsku",
  "@newKey": {
    "description": "Opis dla deweloperów"
  }
}
```

### Krok 3: Regeneruj pliki
```bash
~/flutter/bin/flutter gen-l10n
```

### Krok 4: Użyj w kodzie
```dart
Text(l10n.newKey)
```

## Dostępne języki
- **pl** - Polski (domyślny)
- **en** - English

## Aktualnie dostępne klucze:
- `appTitle` - Tytuł aplikacji
- `homeTitle` - Tytuł ekranu głównego
- `settings` - Ustawienia
- `language` - Język
- `polish` - Polski
- `english` - Angielski
- `welcome` - Wiadomość powitalna
- `save` - Zapisz
- `cancel` - Anuluj
- `ok` - OK
- `error` - Błąd
- `success` - Sukces

## Backend Service: LocaleService

Plik: `lib/services/locale_service.dart`

**Metody:**
- `changeLocale(Locale newLocale)` - Zmienia locale
- `changeLanguage(String languageCode)` - Zmienia język przez kod ('pl', 'en')
- `isPolish` - Czy aktualny język to polski
- `isEnglish` - Czy aktualny język to angielski
- `supportedLocales` - Lista wspieranych języków

## Konfiguracja (pubspec.yaml)

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: any

flutter:
  generate: true
```

## Konfiguracja (l10n.yaml)

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```
