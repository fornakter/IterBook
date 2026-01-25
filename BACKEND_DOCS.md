# Backend Documentation - IterBook

## Architektura Backend

### 1. Models (`lib/models/`)

#### Book Model (`book.dart`)
Model reprezentujący książkę/dokument PDF w aplikacji.

**Pola:**
- `id` - Unikalny identyfikator książki
- `title` - Tytuł książki (domyślnie nazwa pliku)
- `author` - Autor (opcjonalny)
- `filePath` - Ścieżka do pliku PDF
- `currentPage` - Aktualna strona (progress czytania)
- `totalPages` - Całkowita liczba stron
- `dateAdded` - Data dodania książki
- `lastRead` - Data ostatniego czytania
- `currentWordIndex` - Aktualny indeks słowa w RSVP (domyślnie 0)
- `totalWords` - Całkowita liczba słów (domyślnie 0)
- `lastWpm` - Ostatnia używana prędkość WPM (domyślnie 300)

**Właściwości obliczane:**
- `progress` - Progress stron jako wartość 0.0-1.0
- `rsvpProgress` - Progress RSVP jako wartość 0.0-1.0
- `isStarted` - Czy książka została rozpoczęta (strona lub słowo > 0)
- `isCompleted` - Czy książka została ukończona (strony)
- `isRsvpCompleted` - Czy RSVP ukończone (słowa)

**Metody:**
- `copyWith()` - Tworzy kopię z zaktualizowanymi polami
- `toJson()` / `fromJson()` - Serializacja do/z JSON
- `toJsonString()` / `fromJsonString()` - Serializacja do/z String

**Użycie:**
```dart
final book = Book(
  id: 'unique_id',
  title: 'My Book',
  filePath: '/path/to/book.pdf',
  dateAdded: DateTime.now(),
);

// Aktualizacja progress
final updated = book.copyWith(currentPage: 50, totalPages: 100);
print(updated.progress); // 0.5
```

---

### 2. Services (`lib/services/`)

#### BookService (`book_service.dart`)
Serwis zarządzający książkami w aplikacji. Używa `ChangeNotifier` do powiadamiania UI o zmianach.

**Główne funkcje:**
- Przechowywanie listy książek w `SharedPreferences`
- Automatyczne sortowanie (ostatnio czytane na górze)
- Powiadomienia o zmianach dla UI (reactive)

**API:**

```dart
// Inicjalizacja serwisu
final bookService = BookService();
await bookService.initialize();

// Dodawanie książki
await bookService.addBook(book);

// Aktualizacja książki
final updated = book.copyWith(currentPage: 25);
await bookService.updateBook(updated);

// Usuwanie książki
await bookService.removeBook(bookId);

// Pobieranie książki po ID
final book = bookService.getBookById(bookId);

// Aktualizacja progress (strony)
await bookService.updateProgress(bookId, currentPage);

// Aktualizacja progress RSVP (słowa)
await bookService.updateRsvpProgress(
  bookId,
  currentWordIndex: 150,
  totalWords: 1000,
  lastWpm: 350,
);

// Inicjalizacja sesji RSVP
await bookService.initializeRsvpSession(
  bookId,
  totalWords: 1000,
  wpm: 300,
);

// Statystyki
print(bookService.totalBooks);
print(bookService.booksInProgress);
print(bookService.completedBooks);
```

**Storage:**
- Klucz: `books_list`
- Format: JSON array z serializowanymi obiektami Book
- Automatyczne zapisywanie po każdej zmianie

**Sortowanie:**
1. Książki z `lastRead` (ostatnio czytane na górze)
2. Książki bez `lastRead` (sortowane po `dateAdded`)

---

#### FilePickerService (`file_picker_service.dart`)
Serwis obsługujący wybór plików PDF z urządzenia.

**API:**

```dart
final filePickerService = FilePickerService();

// Wybór pliku PDF
final book = await filePickerService.pickPdfFile();
if (book != null) {
  await bookService.addBook(book);
}

// Walidacja pliku
bool isValid = filePickerService.isPdfFile(filePath);

// Rozmiar pliku
final size = await filePickerService.getFileSize(filePath);
final formatted = filePickerService.formatFileSize(size);

// Dostępność pliku
bool accessible = await filePickerService.isFileAccessible(filePath);
```

**Funkcje:**
- Picker z filtrem tylko dla PDF
- Automatyczne generowanie ID i tytułu z nazwy pliku
- Walidacja istnienia pliku
- Formatowanie rozmiaru pliku (B, KB, MB, GB)

---

#### LocaleService (`locale_service.dart`)
Serwis zarządzający językiem aplikacji.

**API:**
```dart
final localeService = LocaleService();

// Zmiana języka
localeService.changeLanguage('pl'); // Polski
localeService.changeLanguage('en'); // Angielski

// Sprawdzanie aktualnego języka
if (localeService.isPolish) { ... }
if (localeService.isEnglish) { ... }

// Lista wspieranych języków
final locales = LocaleService.supportedLocales; // [Locale('pl'), Locale('en')]
```

---

#### PdfParserService (`pdf_parser_service.dart`)
Serwis do parsowania plików PDF i ekstrakcji tekstu.

**Główne funkcje:**
- Ekstrakcja tekstu z całego PDF lub pojedynczych stron
- Podział tekstu na słowa z konfigurowalnymi opcjami
- Walidacja i diagnostyka plików PDF
- Pobieranie metadanych PDF

**API - Ekstrakcja tekstu:**

```dart
final pdfParser = PdfParserService();

// Ekstrakcja tekstu z całego dokumentu
final result = await pdfParser.extractText('/path/to/book.pdf');
if (result.success) {
  print(result.text);       // Cały tekst z PDF
  print(result.pageCount);  // Liczba stron
} else {
  print(result.errorMessage);
  print(result.errorType);  // PdfErrorType enum
}

// Ekstrakcja z konkretnej strony (0-indexed)
final pageResult = await pdfParser.extractTextFromPage('/path/to/book.pdf', 5);

// Ekstrakcja z zakresu stron
final rangeResult = await pdfParser.extractTextFromRange('/path/to/book.pdf', 0, 10);

// Tylko liczba stron (szybkie)
final pageCount = await pdfParser.getPageCount('/path/to/book.pdf');
```

**API - Podział na słowa:**

```dart
// Podstawowa ekstrakcja słów
final words = pdfParser.extractWords(
  text,
  toLowerCase: false,      // Czy zamienić na małe litery
  removePunctuation: true, // Czy usunąć interpunkcję
  removeNumbers: false,    // Czy usunąć liczby
  minWordLength: 1,        // Minimalna długość słowa
  maxWordLength: 100,      // Maksymalna długość słowa
);
print(words.words);           // Lista słów
print(words.totalWordCount);  // Liczba słów

// Unikalne słowa
final unique = pdfParser.extractUniqueWords(text, toLowerCase: true);

// Częstotliwość słów
final frequency = pdfParser.getWordFrequency(text);
// {'słowo': 5, 'inne': 3, ...}
```

**API - Walidacja PDF:**

```dart
// Sprawdzenie czy PDF jest prawidłowy
final isValid = await pdfParser.isValidPdf('/path/to/book.pdf');

// Sprawdzenie czy PDF jest zaszyfrowany
final isEncrypted = await pdfParser.isEncrypted('/path/to/book.pdf');

// Pobranie metadanych PDF
final metadata = await pdfParser.getMetadata('/path/to/book.pdf');
// {
//   'title': 'Book Title',
//   'author': 'Author Name',
//   'subject': '...',
//   'keywords': '...',
//   'creator': 'Software',
//   'producer': 'PDF Producer',
//   'creationDate': '2026-01-01...',
//   'modificationDate': '2026-01-15...',
//   'pageCount': '245'
// }
```

**Typy błędów (PdfErrorType):**
- `fileNotFound` - Plik nie istnieje
- `fileNotReadable` - Brak uprawnień do odczytu
- `invalidFormat` - Nieprawidłowy format PDF
- `encrypted` - PDF zabezpieczony hasłem
- `corrupted` - Uszkodzony plik
- `emptyDocument` - Pusty dokument lub brak tekstu
- `unknown` - Nieznany błąd

**Zależność:**
```yaml
syncfusion_flutter_pdf: ^28.1.33
```

---

#### RsvpService (`rsvp_service.dart`)
Silnik RSVP (Rapid Serial Visual Presentation) do szybkiego czytania słowo po słowie.

**Główne funkcje:**
- Timer do wyświetlania słów z konfigurowalną prędkością (WPM)
- Kontrola odtwarzania: play/pause/stop
- Nawigacja: next/prev word, skip forward/backward
- Statystyki czytania

**API - Ładowanie treści:**

```dart
final rsvp = RsvpService();

// Załaduj listę słów
rsvp.loadWords(['Hello', 'world', 'this', 'is', 'RSVP']);

// Lub załaduj tekst (automatyczny podział na słowa)
rsvp.loadText('Hello world this is RSVP reading');

// Wyczyść treść
rsvp.clear();
```

**API - Kontrola odtwarzania:**

```dart
rsvp.play();           // Start/resume
rsvp.pause();          // Pause
rsvp.togglePlayPause(); // Toggle play/pause
rsvp.stop();           // Stop and reset to beginning
rsvp.restart();        // Reset to beginning
```

**API - Nawigacja:**

```dart
rsvp.nextWord();           // Następne słowo
rsvp.previousWord();       // Poprzednie słowo
rsvp.skipForward(10);      // Przeskocz 10 słów do przodu
rsvp.skipBackward(10);     // Przeskocz 10 słów wstecz
rsvp.jumpToIndex(50);      // Skocz do słowa #50
rsvp.jumpToProgress(0.5);  // Skocz do 50% tekstu
```

**API - Prędkość (WPM):**

```dart
rsvp.setWpm(300);      // Ustaw 300 słów na minutę
rsvp.increaseSpeed();  // Zwiększ o 50 WPM
rsvp.decreaseSpeed();  // Zmniejsz o 50 WPM

// Limity: minWpm=100, maxWpm=1000, step=50
```

**API - Gettery stanu:**

```dart
rsvp.currentWord       // Aktualne słowo do wyświetlenia
rsvp.currentIndex      // Indeks aktualnego słowa
rsvp.totalWords        // Całkowita liczba słów
rsvp.progress          // Progress 0.0-1.0
rsvp.remainingWords    // Pozostałe słowa
rsvp.remainingTimeFormatted  // "05:30" format

rsvp.isPlaying         // Czy odtwarza
rsvp.isPaused          // Czy zatrzymane
rsvp.isFinished        // Czy zakończone
rsvp.state             // RsvpState enum
```

**Stany (RsvpState):**
- `idle` - Brak treści
- `ready` - Treść załadowana, nie odtwarza
- `playing` - Odtwarza
- `paused` - Zatrzymane
- `finished` - Zakończone

**Użycie w UI (ListenableBuilder):**

```dart
ListenableBuilder(
  listenable: rsvpService,
  builder: (context, child) {
    return Column(
      children: [
        // Wyświetlanie słowa (centrowane)
        Center(
          child: Text(
            rsvpService.currentWord,
            style: TextStyle(fontSize: 48),
          ),
        ),
        // Kontrolki
        Row(
          children: [
            IconButton(
              icon: Icon(rsvpService.isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: rsvpService.togglePlayPause,
            ),
            Text('${rsvpService.wordsPerMinute} WPM'),
          ],
        ),
        // Progress bar
        LinearProgressIndicator(value: rsvpService.progress),
      ],
    );
  },
)
```

---

#### ReadingSessionService (`reading_session_service.dart`)
Serwis integrujący PdfParserService, RsvpService i ReadingProgressService dla kompletnej sesji czytania z automatycznym zapisywaniem postępu.

**API:**

```dart
// Tworzenie z BookService (włącza auto-save)
final session = ReadingSessionService(
  bookService: bookService,
  autoSaveInterval: 10, // Zapisuj co 10 słów
);

// Rozpocznij sesję - automatycznie wznawia z zapisanej pozycji
final result = await session.startSession(book);
if (result.success) {
  print('Załadowano ${result.totalWords} słów');
  if (result.resumed) {
    print('Wznowiono z zapisanej pozycji');
  }
  session.rsvp.play(); // Rozpocznij RSVP
}

// Wymuś restart od początku
final result = await session.startSession(book, forceRestart: true);

// Ręczne zapisanie postępu
await session.saveProgress();

// Reset postępu (zacznij od nowa)
await session.resetProgress();

// Zakończ sesję (automatycznie zapisuje)
await session.endSession();

// Gettery
session.currentBook      // Aktualna książka
session.canSaveProgress  // Czy można zapisać postęp
session.progress         // ReadingProgressService
```

---

#### ReadingProgressService (`reading_progress_service.dart`)
Serwis do automatycznego zapisywania postępu czytania.

**Główne funkcje:**
- Auto-save co N słów (domyślnie 10)
- Wznowienie czytania z zapisanej pozycji
- Zapis WPM i pozycji słowa

**API:**

```dart
final progress = ReadingProgressService(
  bookService: bookService,
  rsvpService: rsvpService,
  autoSaveInterval: 10,
);

// Rozpocznij śledzenie
await progress.startTracking(book);

// Ręczne zapisanie
await progress.saveProgress();

// Zatrzymaj śledzenie (zapisuje automatycznie)
await progress.stopTracking();

// Konfiguracja
progress.setAutoSaveInterval(20);  // Zmień interwał
progress.setAutoSaveEnabled(false); // Wyłącz auto-save

// Reset postępu
await progress.resetProgress(bookId);

// Gettery
progress.isDirty         // Czy są niezapisane zmiany
progress.hasActiveSession // Czy sesja aktywna
progress.autoSaveInterval // Interwał auto-save
```

---

## Integracja w UI

### MenuScreen

MenuScreen używa `ListenableBuilder` do reaktywnego renderowania listy książek:

```dart
ListenableBuilder(
  listenable: bookService,
  builder: (context, child) {
    if (!bookService.isLoaded) {
      bookService.initialize();
      return CircularProgressIndicator();
    }

    final books = bookService.books;
    // Render books...
  },
)
```

**Funkcjonalności:**
- ✅ Wyświetlanie listy książek
- ✅ Dodawanie nowych PDF przez FloatingActionButton
- ✅ Długie kliknięcie na książkę → opcje (info, usuwanie)
- ✅ Kliknięcie na książkę → otwiera ReadingScreen
- ✅ Progress bar dla każdej książki
- ✅ Ikona ✓ dla ukończonych książek
- ✅ Pusty stan ("No books yet")

---

## Zależności

### Pakiety dodane do `pubspec.yaml`:
```yaml
dependencies:
  file_picker: ^8.1.4           # Wybór plików PDF
  path_provider: ^2.1.5         # Dostęp do katalogów systemu
  shared_preferences: ^2.3.3    # Persistencja danych
  path: ^1.9.0                  # Operacje na ścieżkach
  syncfusion_flutter_pdf: ^28.1.33  # Parsowanie PDF i ekstrakcja tekstu
```

---

## Flow dodawania książki

1. **User** kliknie FloatingActionButton (+)
2. **MenuScreen** wywołuje `_handleAddBook()`
3. **FilePickerService** otwiera picker z filtrem PDF
4. **User** wybiera plik PDF
5. **FilePickerService** tworzy obiekt `Book`:
   - ID: `{fileName}_{timestamp}`
   - Title: nazwa pliku bez rozszerzenia
   - FilePath: pełna ścieżka
   - DateAdded: DateTime.now()
6. **BookService** dodaje książkę do listy
7. **BookService** zapisuje do SharedPreferences
8. **BookService** wywołuje `notifyListeners()`
9. **MenuScreen** automatycznie re-renderuje listę
10. **User** widzi nową książkę na liście

---

## Flow parsowania PDF

1. **Frontend** otrzymuje ścieżkę do PDF (z FilePickerService)
2. **Frontend** wywołuje `PdfParserService.extractText(filePath)`
3. **PdfParserService** waliduje plik (istnienie, format, szyfrowanie)
4. **PdfParserService** ekstrakcja tekstu strona po stronie
5. **PdfParserService** zwraca `PdfParseResult`:
   - `success: true` → `text`, `pageCount`
   - `success: false` → `errorMessage`, `errorType`
6. **Frontend** może podzielić tekst na słowa używając `extractWords()`
7. **Frontend** może wyświetlić słowa użytkownikowi

**Obsługa błędów w UI:**
```dart
final result = await pdfParser.extractText(book.filePath);
if (!result.success) {
  switch (result.errorType) {
    case PdfErrorType.encrypted:
      showDialog(...); // "PDF jest zabezpieczony hasłem"
      break;
    case PdfErrorType.emptyDocument:
      showDialog(...); // "PDF nie zawiera tekstu (tylko obrazy?)"
      break;
    default:
      showDialog(...); // Ogólny błąd
  }
}
```

---

## Flow RSVP (szybkie czytanie)

1. **User** klika na książkę w MenuScreen
2. **ReadingScreen** tworzy `ReadingSessionService`
3. **ReadingSessionService** wywołuje `startSession(book)`:
   - PdfParserService ekstrakcja tekstu
   - Podział na słowa
   - Załadowanie do RsvpService
4. **ReadingScreen** wyświetla UI z ListenableBuilder:
   - Centrowane słowo (`rsvp.currentWord`)
   - Kontrolki play/pause
   - Slider WPM
   - Progress bar
5. **User** klika Play
6. **RsvpService** startuje Timer
7. Timer wywołuje `nextWord()` co `millisecondsPerWord`
8. **RsvpService** wywołuje `notifyListeners()`
9. **ReadingScreen** automatycznie aktualizuje wyświetlane słowo
10. Po zakończeniu: `state = RsvpState.finished`

**Przykład UI ReadingScreen:**
```dart
class ReadingScreen extends StatefulWidget {
  final Book book;
  // ...
}

class _ReadingScreenState extends State<ReadingScreen> {
  final ReadingSessionService _session = ReadingSessionService();

  @override
  void initState() {
    super.initState();
    _session.startSession(widget.book);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListenableBuilder(
        listenable: _session.rsvp,
        builder: (context, _) {
          return Center(
            child: Text(
              _session.rsvp.currentWord,
              style: TextStyle(fontSize: 48),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _session.rsvp.togglePlayPause,
        child: Icon(_session.rsvp.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }
}
```

---

## Persistence

Książki są zapisywane w `SharedPreferences` pod kluczem `books_list` jako JSON:

```json
[
  {
    "id": "MyBook_1234567890",
    "title": "My Book",
    "author": null,
    "filePath": "/path/to/book.pdf",
    "currentPage": 25,
    "totalPages": 100,
    "dateAdded": "2026-01-23T10:30:00.000",
    "lastRead": "2026-01-23T11:45:00.000",
    "currentWordIndex": 150,
    "totalWords": 5000,
    "lastWpm": 350
  }
]
```

---

## Statystyki BookService

```dart
bookService.totalBooks        // Wszystkie książki
bookService.booksInProgress   // Rozpoczęte, nieukończone
bookService.completedBooks    // Ukończone (currentPage >= totalPages)
bookService.notStartedBooks   // Nierozpoczęte (currentPage == 0)
```

---

## Debugging

```dart
// Włącz debug printy w FilePickerService i BookService
debugPrint('Successfully picked PDF: ${book.title}');
debugPrint('Error loading books: $e');

// Wyczyść wszystkie książki (tylko do testów!)
await bookService.clearAllBooks();
```

---

## TODO dla Frontend

### RSVP UI (priorytet: WYSOKI)
- [ ] ReadingScreen: wyświetlanie słowa centrowane (horizontal + vertical)
- [ ] Kontrolki play/pause (użyj `rsvp.togglePlayPause()`)
- [ ] Slider/kontrolka WPM (użyj `rsvp.setWpm()`, zakres 100-1000)
- [ ] Progress bar (użyj `rsvp.progress`)
- [ ] Wyświetlanie pozostałego czasu (`rsvp.remainingTimeFormatted`)
- [ ] Nawigacja: przyciski skip forward/backward
- [ ] Obsługa stanów: loading, error, finished

### Inne
- [ ] Implementacja wyświetlania PDF (pdf_viewer package)
- [ ] Zapisywanie currentPage podczas czytania
- [ ] Dodanie pola 'author' w UI (edit book dialog)
- [ ] Dodanie totalPages z PDF metadata (użyj `PdfParserService.getPageCount()`)
- [ ] Tłumaczenia dla tekstów w menu_screen.dart
- [ ] Ikona książki/cover w book card
- [ ] Filtrowanie/sortowanie książek
- [ ] Obsługa błędów PDF w UI (encrypted, corrupted, etc.)

---

## Bezpieczeństwo

- ✅ Walidacja rozszerzenia pliku (.pdf)
- ✅ Sprawdzenie istnienia pliku przed dodaniem
- ✅ Try-catch na operacjach I/O
- ✅ Unique ID dla każdej książki
- ✅ Null safety dla opcjonalnych pól
