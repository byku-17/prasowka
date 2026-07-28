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

      return await compute(_extractMainContentCompute, decodedBody);
    } catch (e) {
      debugPrint('ReaderService Error: $e');
      return null;
    }
  }

  Future<String> _resolveUrl(String url) async {
    if (!url.contains('news.google.com')) return url;
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      final body = response.body;

      // Google News uses <meta http-equiv="refresh" content="0; url=...">
      final metaRefresh = RegExp(
        r"""<meta[^>]*http-equiv=["']?refresh["']?[^>]*content=["']?\d+;\s*url=([^"'>\s]+)""",
        caseSensitive: false,
      );
      final metaMatch = metaRefresh.firstMatch(body);
      if (metaMatch != null) {
        final redirectUrl = metaMatch.group(1)!;
        if (redirectUrl.startsWith('http')) return redirectUrl;
        return Uri.parse(url).resolve(redirectUrl).toString();
      }

      // Also check for window.location or location.href in scripts
      final locationRedirect = RegExp(r"""window\.location(?:\.href)?\s*=\s*["']([^"']+)["']""");
      final locMatch = locationRedirect.firstMatch(body);
      if (locMatch != null) {
        final redirectUrl = locMatch.group(1)!;
        if (redirectUrl.startsWith('http')) return redirectUrl;
      }

      // Check for data-n-au attribute (new Google News format)
      final dataNAu = RegExp(r'data-n-au="([^"]+)"');
      final nauMatch = dataNAu.firstMatch(body);
      if (nauMatch != null) {
        final encoded = nauMatch.group(1)!;
        try {
          final decoded = utf8.decode(base64Url.decode(encoded));
          if (decoded.startsWith('http')) return decoded;
        } catch (_) {}
      }
    } catch (_) {}
    return url;
  }
}

String? _extractMainContentCompute(String htmlBody) {
  try {
    final document = html_parser.parse(htmlBody);
    document.querySelectorAll('script, style, nav, footer, header, noscript, iframe, .ads, .social-share, source, picture, figure figcaption').forEach((e) => e.remove());

    dom.Element? bestElement;
    int maxParagraphs = 0;

    final articles = document.querySelectorAll('article');
    if (articles.isNotEmpty) {
      bestElement = articles.reduce((a, b) => a.text.length > b.text.length ? a : b);
    } else {
      final containers = document.querySelectorAll('div, section, main');
      for (var container in containers) {
        final pCount = container.querySelectorAll('p').length;
        if (pCount > maxParagraphs) {
          maxParagraphs = pCount;
          bestElement = container;
        }
      }
    }

    if (bestElement != null) {
      bestElement.querySelectorAll('button, form, .related-articles, .comments').forEach((e) => e.remove());
      return bestElement.innerHtml;
    }
    return null;
  } catch (e) {
    return null;
  }
}
