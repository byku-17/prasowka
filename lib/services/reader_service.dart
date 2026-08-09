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
      return normalizeHtml(extracted);
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
