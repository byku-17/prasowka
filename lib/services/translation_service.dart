import 'package:translator/translator.dart';
import 'package:flutter/foundation.dart';

class TranslationService {
  final GoogleTranslator _translator = GoogleTranslator();

  /// Tłumaczy podany tekst na język polski (pl) z obsługą długich tekstów (chunking)
  Future<String?> translate(String text) async {
    if (text.isEmpty) return text;
    
    try {
      // Jeśli tekst jest krótki, tłumaczymy go w całości
      if (text.length < 2000) {
        return await _translateWithRetry(text);
      }

      // Jeśli tekst jest długi (np. pełny artykuł), dzielimy go na mniejsze części
      // Zmniejszamy rozmiar paczki do 2500 znaków dla większego bezpieczeństwa
      debugPrint('Sowa Translator: Tekst jest długi (${text.length} znaków). Dzielę na części...');
      
      final List<String> chunks = _splitIntoChunks(text, 2500);
      final List<String> translatedChunks = [];

      for (int i = 0; i < chunks.length; i++) {
        debugPrint('Sowa Translator: Tłumaczę część ${i + 1} z ${chunks.length}...');
        final t = await _translateWithRetry(chunks[i]);
        if (t != null) {
          translatedChunks.add(t);
        } else {
          // Jeśli nawet po retry zawiedzie, dodajemy oryginał, żeby nie przerywać całego procesu
          translatedChunks.add(chunks[i]);
        }
        
        // Większe opóźnienie między częściami (600ms), aby uniknąć blokad IP
        await Future.delayed(const Duration(milliseconds: 600));
      }

      return translatedChunks.join(' ');
    } catch (e) {
      debugPrint('Sowa Translation Global Error: $e');
      return null;
    }
  }

  /// Próbuje przetłumaczyć tekst, ponawiając próbę w razie błędu (max 3 razy)
  Future<String?> _translateWithRetry(String text, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final translation = await _translator.translate(text, to: 'pl');
        return translation.text;
      } catch (e) {
        attempts++;
        debugPrint('Sowa Translator: Próba $attempts nieudana. Retrying...');
        if (attempts < maxRetries) {
          await Future.delayed(Duration(seconds: attempts)); // Coraz dłuższe czekanie
        }
      }
    }
    return null;
  }

  /// Dzieli tekst na części, próbując nie przerywać w środku wyrazu
  List<String> _splitIntoChunks(String text, int maxChunkSize) {
    List<String> chunks = [];
    int start = 0;
    while (start < text.length) {
      int end = start + maxChunkSize;
      if (end > text.length) end = text.length;
      
      // Próbujemy cofnąć się do spacji, aby nie ciąć wyrazów
      if (end < text.length) {
        int lastSpace = text.lastIndexOf(' ', end);
        if (lastSpace > start) end = lastSpace;
      }
      
      chunks.add(text.substring(start, end));
      start = end;
    }
    return chunks;
  }

  /// Sprawdza (heurystycznie), czy tekst jest w języku polskim
  /// (Uproszczone: szukamy charakterystycznych polskich znaków)
  bool isProbablyPolish(String text) {
    final polishChars = RegExp(r'[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]');
    return polishChars.hasMatch(text);
  }
}
