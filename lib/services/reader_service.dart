import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:flutter/foundation.dart';

class ReaderService {
  Future<String?> extractFullContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
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
