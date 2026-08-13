import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/foundation.dart';

class ReaderService {
  Future<String?> extractFullContent(String url) async {
    try {
      final resolvedUrl = await _resolveUrl(url);
      final response = await http.get(Uri.parse(resolvedUrl)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      String decodedBody;
      try {
        decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
      } catch (_) {
        decodedBody = latin1.decode(response.bodyBytes);
      }

      final extracted = await compute(_extractMainContentCompute, decodedBody);
      if (extracted == null) return null;
      // Usuń bloki-śmieci (przypisy, CTA, „zobacz także", zgody cookies itp.)
      // przed finalną normalizacją odstępów.
      return normalizeHtml(stripJunkBlocks(extracted));
    } catch (e) {
      debugPrint('ReaderService Error: $e');
      return null;
    }
  }

  /// Usuwa zbędne odstępy z treści HTML:
  /// - serie 2+ znaczników <br> zamienia na jeden,
  /// - usuwa puste akapity (<p></p>, <p><br></p> itd.),
  /// - zwija 3+ nowe linie do dwóch (na wypadek treści tekstowej).
  static String normalizeHtml(String html) {
    if (html.isEmpty) return html;
    var s = html;
    s = s.replaceAll(RegExp(r'(?:<br\s*/?>\s*){2,}', caseSensitive: false), '<br>');
    s = s.replaceAll(
      RegExp(r'<p\b[^>]*>\s*(?:<br\s*/?>\s*)*</p>', caseSensitive: false),
      '',
    );
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s;
  }

  /// Wzorce bloków-śmieci (przypisy, CTA, „zobacz także", newslettery,
  /// zgody cookies, byline-y itp.), które nie są treścią artykułu.
  static final List<RegExp> _junkBlockPatterns = [
    // Powiązane / „czytaj dalej"
    RegExp(r'^zobacz\s+(także|też|równie?ż|wiecej|więcej)\b'),
    RegExp(r'^przeczytaj\s+(także|też|równie?ż|wiecej|więcej|dalej)\b'),
    RegExp(r'^czytaj\s+(także|też|równie?ż|dalej)\b'),
    RegExp(r'^podobne\s+artykuł[yi]'),
    RegExp(r'^polecamy\b'),
    RegExp(r'^może\s+cię\s+zainteresować\b'),
    RegExp(r'^wiecej\s+na\s+ten\s+temat\b'),
    RegExp(r'^więcej\s+na\s+ten\s+temat\b'),
    RegExp(r'^redakcja\s+poleca\b'),
    RegExp(r'^także\s+w\s+(temi?e|dziale)\b'),
    // Byline / autor / źródło zdjęcia
    RegExp(r'^źr[óo]dł[oa]:'),
    RegExp(r'''^fot\.?[\s"':]'''),
    RegExp(r'^\(?\s*(pap|reuters|afp)\b'),
    RegExp(r'^autor(ka)?:'),
    RegExp(r'^opracowanie:'),
    RegExp(r'^redakcja:'),
    RegExp(r'^tekst:'),
    // Newslettery / obserwowanie
    RegExp(r'newsl[ae]tter'),
    RegExp(r'^zapisz\s+się\s+do'),
    RegExp(r'^bądź\s+na\s+bieżąco\b'),
    RegExp(r'^dołącz\s+do\s+nas\b'),
    RegExp(r'^zaobserwuj\s+nas\b'),
    RegExp(r'^polub\s+nas\b'),
    RegExp(r'^śledź\s+nas\b'),
    RegExp(r'^subskrybuj\b'),
    // Społecznościowe / komentarze
    RegExp(r'^udostępnij\b'),
    RegExp(r'^podziel\s+się\b'),
    RegExp(r'^skomentuj\b'),
    RegExp(r'^prześlij\b'),
    // Zgody cookies / RODO
    RegExp(r'plik[ui]?\s+cooki'),
    RegExp(r'^cookies\b'),
    RegExp(r'^wyrażam\s+[zg]godę'),
    RegExp(r'^zgoda\s+na\s+[zp]rzetwarzanie'),
    RegExp(r'^polityk[ae]\s+prywatno'),
    // Nagłówki sekcji przypisów
    RegExp(r'^(przypisy|footnotes)\s*[\d:.]*$'),
  ];

  /// Usuwa z treści HTML bloki, które nie są treścią artykułu:
  /// - akapity zaczynające się od „Zobacz/Zobacz także/Przeczytaj też/…",
  /// - linie „Źródło:", „fot. …", „(PAP)", byline-y,
  /// - CTA newslettera, zgody cookies, „udostępnij/podziel się",
  /// - bloki zawierające wyłącznie link (np. listę powiązanych artykułów).
  /// Obiekt blok jest usuwany tylko gdy jest krótki (do [_junkMaxChars])
  /// lub pasuje do nagłówka sekcji przypisów — chroni to właściwe akapity,
  /// które przelotnie zawierają słowa typu „komentarze"/„newsletter".
  static const int _junkMaxChars = 240;

  static String stripJunkBlocks(String html) {
    if (html.trim().isEmpty) return html;
    try {
      final doc = html_parser.parse(html);
      final candidates = doc.querySelectorAll('p, li, blockquote, h2, h3, div, section, aside');
      final junkByDepth = <dom.Element, bool>{};
      for (final el in candidates) {
        // Pomiń elementy, które są już w usuniętym rodzicu.
        var parent = el.parent;
        var insideRemoved = false;
        while (parent != null) {
          if (junkByDepth[parent] == true) {
            // Gdy rodzic jest śmieciem, sami jesteśmy objęci — pomiń.
            insideRemoved = true;
            break;
          }
          parent = parent.parent;
        }
        if (insideRemoved) continue;

        final rawText = el.text.trim();
        if (rawText.isEmpty) continue;
        final text = rawText.toLowerCase();

        // 1) Blok zawierający wyłącznie URL (np. stopka źródła).
        if (_isOnlyUrl(text)) {
          el.remove();
          junkByDepth[el] = true;
          continue;
        }
        // 2) Nagłówek sekcji przypisów — usuń zawsze.
        if (_junkBlockPatterns.any((r) => r.hasMatch(text) && (text.length <= 40))) {
          el.remove();
          junkByDepth[el] = true;
          continue;
        }
        // 3) Inne wzorce śmieci — tylko dla krótkich bloków.
        if (text.length <= _junkMaxChars &&
            _junkBlockPatterns.any((r) => r.hasMatch(text))) {
          el.remove();
          junkByDepth[el] = true;
          continue;
        }
        // 4) Lista linków bez tekstu (np. „Zobacz także: [link] [link] [link]").
        if (rawText.length <= _junkMaxChars &&
            el.querySelectorAll('a[href]').isNotEmpty &&
            el.querySelectorAll('p').isEmpty) {
          final nonLinkText = rawText.split(' ').length;
          if (nonLinkText <= 8) {
            el.remove();
            junkByDepth[el] = true;
          }
        }
      }
      // Wyczyść teraz puste kontenery po usunięciu dzieci.
      _removeEmptyContainers(doc);
      return doc.body?.innerHtml ?? html;
    } catch (_) {
      return html;
    }
  }

  static bool _isOnlyUrl(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    return RegExp(r'^(https?://\S+|www\.\S+)$').hasMatch(t);
  }

  /// Usuwa kontenery (div/section), które po czyszczeniu nie mają już
  /// żadnych bloków treści (ułatwia to dalszą normalizację).
  static void _removeEmptyContainers(dom.Document doc) {
    for (final el in doc.querySelectorAll('div, section, article')) {
      final blockChildren = el.children.where((c) =>
          c.localName != null &&
          const {'script', 'style', 'img', 'figure'}.contains(c.localName) == false);
      if (blockChildren.isEmpty && el.text.trim().isEmpty) {
        el.remove();
      }
    }
  }

  /// Usuwa z tekstu inline znaczniki przypisów, które zostały w treści:
  /// „[1]", „[2]", liczniki w nawiasach i indeksy górne.
  /// Używane głównie przez lektora TTS (czysta lektura bez śmieci).
  static String stripInlineFootnoteMarkers(String text) {
    if (text.isEmpty) return text;
    var t = text;
    // Indeksy górne/nawołania typu [1], [b], (i), †
    t = t.replaceAll(RegExp(r'\[\s*\d+\s*\]'), '');
    t = t.replaceAll(RegExp(r'\(?\s*[†#*]\s*\)?'), ' ').replaceAll(RegExp(r'\s{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\[\s*[\u0000-\u007F]{1,3}\s*\]'), '');
    // Usuń zaległe spacje przed interpunkcją (np. „dalej [1]." → „dalej.").
    t = t.replaceAllMapped(RegExp(r'\s+([.,!?;:…—-])'), (m) => m.group(1)!);
    return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  /// Sprawdza, czy pierwszy akapit treści (HTML) powtarza podany opis/lead.
  /// Używane do uniknięcia zdublowanego pierwszego akapitu na ekranie
  /// artykułu, gdy opis z RSS == początek wyekstrahowanej pełnej treści.
  static bool isLeadDuplicated(String? description, String contentHtml) {
    if (description == null || description.trim().isEmpty) return false;
    final desc = _normalizedForCompare(description);
    if (desc.isEmpty) return false;
    final lead = _normalizedForCompare(contentHtml.replaceAll(RegExp(r'<[^>]*>'), ' '));
    if (lead.isEmpty) return false;
    return lead.startsWith(desc);
  }

  static String _normalizedForCompare(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> _resolveUrl(String url) async {
    if (!url.contains('news.google.com')) return url;
    // Google News redirect URLs nie mogą być automatycznie rozwiązywane
    // (wymagają JS). Prawdziwy URL powinien być już wyodrębniony podczas
    // parsowania RSS przez RssService.extractRealUrlFromContent().
    // Jeśli tu dotarliśmy, oznacza to że ekstrakcja się nie powiodła.
    debugPrint('ReaderService: Próba otwarcia URL Google News bez wyodrębnionego prawdziwego URL: $url');
    return url;
  }
}

String? _extractMainContentCompute(String htmlBody) {
  try {
    final document = html_parser.parse(htmlBody);
    document.querySelectorAll('script, style, nav, footer, header, noscript, iframe, .ads, .social-share, source, picture, figure figcaption').forEach((e) => e.remove());

    // Usuń podpisy pod zdjęciami i elementy-śmieci (caption/credit/byline),
    // żeby nie trafiały do wyekstrahowanej treści (czytnik + lektor).
    _removeCaptionElements(document);

    // 1) JSON-LD articleBody — najczęściej zawiera PEŁNĄ treść,
    //    podczas gdy DOM po usunięciu JS-owych elementów bywa okrojony.
    final jsonLdBody = _extractJsonLdBody(document);
    if (jsonLdBody != null && jsonLdBody.trim().length >= 350) {
      return _paragraphize(jsonLdBody);
    }

    // 2) Najlepszy kontener — najwięcej TEKSTU w akapitach (nie liczby
    //    akapitów). Mierzony łączną długością, bo liczba <p> bywa myląca.
    dom.Element? bestElement;
    int maxTextLength = 0;
    final articles = document.querySelectorAll('article');
    final containers = articles.isNotEmpty
        ? articles
        : document.querySelectorAll('div, section, main');
    for (final container in containers) {
      final paras = container.querySelectorAll('p');
      if (paras.isEmpty) continue;
      final textLength = paras.fold<int>(
        0,
        (sum, p) => sum + p.text.trim().length,
      );
      if (textLength > maxTextLength) {
        maxTextLength = textLength;
        bestElement = container;
      }
    }

    if (bestElement != null) {
      bestElement.querySelectorAll('button, form, .related-articles, .comments').forEach((e) => e.remove());
      // Gdy kontener pokrywa większość akapitów strony, zwróć go w całości.
      if (maxTextLength >= 350) return bestElement.innerHtml;
    }

    // 3) Awaryjnie: zbierz wszystkie sensowne akapity z całej strony
    //    (pomijając junk) — treść bywa rozbita na kilka kontenerów.
    final merged = _extractMergedParagraphs(document);
    if (merged != null && merged.length >= 350) return merged;

    // Nawet jeśli kontener był krótki — zwróć go (zostanie odrzucony
    // przez próg _hasUsableContent >= 350).
    return bestElement?.innerHtml;
  } catch (e) {
    return null;
  }
}

/// Wyciąga pole `articleBody` z danych JSON-LD (typ NewsArticle itp.).
/// Pomija skrypty bez treści (logo, wydawca itd.).
String? _extractJsonLdBody(dom.Document document) {
  try {
    final scripts = document.querySelectorAll('script[type="application/ld+json"]');
    for (final script in scripts) {
      final raw = script.text.trim();
      if (raw.isEmpty) continue;
      dynamic data;
      try {
        data = jsonDecode(raw);
      } catch (_) {
        continue;
      }
      for (final node in _flattenJsonLdNodes(data)) {
        if (node is Map) {
          final body = node['articleBody'];
          if (body is String && body.trim().length >= 100) {
            return body.trim();
          }
        }
      }
    }
  } catch (_) {}
  return null;
}

List<dynamic> _flattenJsonLdNodes(dynamic data) {
  final result = <dynamic>[];
  if (data is List) {
    for (final item in data) {
      result.addAll(_flattenJsonLdNodes(item));
    }
  } else if (data is Map) {
    result.add(data);
    final graph = data['@graph'];
    if (graph is List) {
      for (final item in graph) {
        result.addAll(_flattenJsonLdNodes(item));
      }
    }
  }
  return result;
}

/// Zamienia zwykły tekst (np. z JSON-LD) na akapity <p>.
String _paragraphize(String text) {
  return text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .map((p) => '<p>${p.replaceAll(RegExp(r'\s*\n\s*'), ' ')}</p>')
      .join();
}

/// Łączy akapity z całego dokumentu, pomijając nawigację, reklamy,
/// sidebar, sekcje powiązane/komentarze i bardzo krótkie fragmenty.
String? _extractMergedParagraphs(dom.Document document) {
  const junkTags = {
    'nav', 'footer', 'aside', 'form', 'button',
    'script', 'style', 'noscript',
  };
  const junkClassWords = {
    'sidebar', 'related', 'recommended', 'comments', 'menu',
    'share', 'social', 'newsletter', 'advert', 'banner', 'widget',
    'caption', 'credit', 'byline', 'figcaption',
  };
  final blocks = <String>[];
  final seen = <String>{};
  for (final p in document.querySelectorAll('p')) {
    var el = p.parent;
    var inJunk = false;
    while (el != null) {
      final cls = el.className.toLowerCase();
      final hasJunkClass = junkClassWords.any(cls.split(' ').contains);
      if (junkTags.contains(el.localName) || hasJunkClass) {
        inJunk = true;
        break;
      }
      el = el.parent;
    }
    if (inJunk) continue;
    final text = p.text.trim();
    if (text.length < 30) continue;
    if (!seen.add(text)) continue;
    blocks.add(p.outerHtml);
  }
  if (blocks.isEmpty) return null;
  return blocks.join();
}

/// Usuwa z dokumentu podpisy pod zdjęciami i elementy oznaczone klasami
/// caption/credit/byline (często pojawiają się na początku lub w środku
/// wyekstrahowanego kontenera i psują start czytania).
void _removeCaptionElements(dom.Document document) {
  try {
    const junkWords = ['caption', 'credit', 'byline', 'creditline', 'photocaption', 'imagecaption', 'figcaption'];
    for (final el in document.querySelectorAll('figcaption, span, div, p, h1, h2, h3, h4, h5, h6, li')) {
      final cls = '${el.attributes['class'] ?? ''} ${el.attributes['id'] ?? ''}'.toLowerCase();
      if (el.localName == 'figcaption' ||
          cls.split(RegExp(r'[\s_-]+')).any((w) => junkWords.contains(w))) {
        el.remove();
      }
    }
  } catch (_) {}
}

/// Czyści surowy HTML artykułu dla lektora TTS:
/// - usuwa podpisy pod zdjęciami i elementy caption/credit/byline,
/// - wyciąga czysty tekst (bez tagów),
/// - usuwa URL-e, linie „Źródło:", „fot.", ©, „Materiał partnera" itd.
/// Dzięki temu lektor zawsze zaczyna od właściwej treści, a nie od przypisu.
String cleanForTts(String raw) {
  if (raw.trim().isEmpty) return '';
  try {
    final doc = html_parser.parse(raw);
    _removeCaptionElements(doc);
    doc.querySelectorAll('script, style').forEach((e) => e.remove());
    final text = doc.body?.text ?? '';
    return _stripTtsJunk(text);
  } catch (_) {
    return _stripTtsJunk(raw.replaceAll(RegExp(r'<[^>]*>'), ' '));
  }
}

String _stripTtsJunk(String text) {
  var t = text;
  t = t.replaceAll(RegExp(r'https?://\S+'), '');
  t = t.replaceAll(RegExp(r'www\.\S+'), '');
  t = t.replaceAll(RegExp(r'Źródło:.*', multiLine: true), '');
  t = t.replaceAll(RegExp(r'fot\.?.*', multiLine: true), '');
  t = t.replaceAll(RegExp(r'photo:.*', caseSensitive: false, multiLine: true), '');
  t = t.replaceAll(RegExp(r'source:.*', caseSensitive: false, multiLine: true), '');
  t = t.replaceAll(RegExp(r'©.*', multiLine: true), '');
  t = t.replaceAll(RegExp(r'Materiał partnera.*', multiLine: true), '');
  t = t.replaceAll(RegExp(r'---.*---', multiLine: true), '');
  t = t.replaceAll(RegExp(r'\[[^\]]*\]'), '');
  t = t.replaceAll(RegExp(r'\(fot\.?\s*\)'), '');
  t = t.replaceAll(RegExp(r'[•■●▪►▶▷▸▹]{2,}'), '');
  t = t.replaceAll(RegExp(r'={3,}'), '');
  t = t.replaceAll(RegExp(r'-{3,}'), '');
  t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  t = ReaderService.stripInlineFootnoteMarkers(t);
  return t.trim();
}
