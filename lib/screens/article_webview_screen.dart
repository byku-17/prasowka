import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prasowka/theme/app_theme.dart';

class ArticleWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final bool useReaderMode;

  const ArticleWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.useReaderMode = true,
  });

  @override
  State<ArticleWebViewScreen> createState() => _ArticleWebViewScreenState();
}

class _ArticleWebViewScreenState extends State<ArticleWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _currentUrl;

  /// Zawsze wstrzykiwane — ukrywa banery cookie/RODO (bez pełnego reader mode)
  static const _hideCookieBanners = '''
    (function() {
      var selectors = [
        '[class*="cookie"]', '[id*="cookie"]',
        '[class*="consent"]', '[id*="consent"]',
        '[class*="rodo"]', '[id*="rodo"]',
        '[class*="gdpr"]', '[id*="gdpr"]',
        '[class*="cmp"]', '[id*="cmp"]',
        '[class*="onetrust"]', '[id*="onetrust"]',
        '[class*="cc-banner"]', '[class*="cc-window"]',
        '[id*="sp_message"]', '[class*="sp_veil"]',
        '[id*="accept-cookies"]', '[class*="accept-cookies"]',
        '[class*="notice"]', '[id*="notice"]',
        '[class*="Privacy"]', '[id*="Privacy"]',
        '[class*="policy"]', '[id*="policy"]',
        'div[class*="QC"]', 'div[id*="QC"]',
        '[class*="CybotCookiebotDialog"]', '[id*="CybotCookiebotDialog"]',
        '[id*="cookieconsent"]', '[class*="cookieconsent"]',
        '[class*="iubenda"]', '[id*="iubenda"]',
        '[class*="cookies-banner"]', '[id*="cookies-banner"]',
        '[class*="cookie-law"]', '[id*="cookie-law"]',
        '[class*="CookieConsent"]', '[id*="CookieConsent"]',
        '[class*="accept-cookie"]', '[id*="accept-cookie"]',
        '[id*="ez-cookie"]', '[class*="ez-cookie"]',
        '[class*="pea_cook"]', '[id*="pea_cook"]',
        '[id*="cookie-notice"]', '[class*="cookie-notice"]',
        '[id*="cookie-wall"]', '[class*="cookie-wall"]'
      ];
      selectors.forEach(function(s) {
        document.querySelectorAll(s).forEach(function(el) {
          el.style.display = 'none';
          el.remove();
        });
      });
      // Ukryj fixed/sticky overlaye (cookie bannery często mają position:fixed)
      document.querySelectorAll('*').forEach(function(el) {
        var cs = window.getComputedStyle(el);
        if ((cs.position === 'fixed' || cs.position === 'sticky') && cs.zIndex > 100) {
          var tag = el.tagName.toLowerCase();
          if (tag !== 'header' && tag !== 'nav' && tag !== 'footer') {
            el.style.display = 'none';
          }
        }
      });
      // Kliknij wszystkie "Akceptuję" / "Accept" / "Zgadzam się" / "OK" przyciski
      var btnTexts = ['akceptuj', 'accept', 'zgodz', 'ok', 'rozumiem', 'przejdź', 'close', 'zamknij'];
      document.querySelectorAll('button, a, [role="button"]').forEach(function(el) {
        var txt = (el.textContent || '').toLowerCase().trim();
        if (btnTexts.some(function(t) { return txt.indexOf(t) === 0; }) && txt.length < 40) {
          try { el.click(); } catch(e) {}
        }
      });
    })();
  ''';

  static const _readerCss = '''
    (function() {
      // 1. Ukryj cookie/RODO banery
      var cookieSelectors = [
        '[class*="cookie"]', '[id*="cookie"]',
        '[class*="consent"]', '[id*="consent"]',
        '[class*="rodo"]', '[id*="rodo"]',
        '[class*="gdpr"]', '[id*="gdpr"]',
        '[class*="cmp"]', '[id*="cmp"]',
        '[class*="onetrust"]', '[id*="onetrust"]',
        '[class*="cc-banner"]', '[class*="cc-window"]',
        '[id*="sp_message"]', '[class*="sp_veil"]',
        '[id*="accept-cookies"]', '[class*="accept-cookies"]',
        '[class*="notice"]', '[id*="notice"]',
        '[class*="Privacy"]', '[id*="Privacy"]',
        '[class*="policy"]', '[id*="policy"]',
        'div[class*="QC"]', 'div[id*="QC"]'
      ];
      cookieSelectors.forEach(function(s) {
        document.querySelectorAll(s).forEach(function(el) {
          el.style.display = 'none';
        });
      });

      // 2. Ukryj reklamy i trackery
      var adSelectors = [
        '[class*="ad-"]', '[class*="ad_"]', '[class*="ads"]',
        '[id*="ad-"]', '[id*="ad_"]', '[id*="ads"]',
        '[class*="banner"]', '[id*="banner"]',
        '[class*="advert"]', '[id*="advert"]',
        '[class*="commercial"]', '[id*="commercial"]',
        '[class*="sponsor"]', '[id*="sponsor"]',
        'iframe[src*="ad"]', 'iframe[src*="doubleclick"]',
        'iframe[src*="googlesyndication"]',
        '[class*="dfp"]', '[id*="dfp"]',
        '[class*="taboola"]', '[id*="taboola"]',
        '[class*="outbrain"]', '[id*="outbrain"]',
        '[class*="gemius"]', '[id*="gemius"]',
        '[id*="google_ads"]', '[class*="google-ads"]',
        'ins.adsbygoogle'
      ];
      adSelectors.forEach(function(s) {
        document.querySelectorAll(s).forEach(function(el) {
          el.style.display = 'none';
        });
      });

      // 3. Ukryj social share, popup, overlay, modale
      var overlaySelectors = [
        '[class*="social-share"]', '[class*="socialShare"]',
        '[class*="popup"]', '[id*="popup"]',
        '[class*="modal"]', '[id*="modal"]',
        '[class*="overlay"]', '[id*="overlay"]',
        '[class*="lightbox"]', '[id*="lightbox"]',
        '[class*="fancybox"]', '[id*="fancybox"]',
        '[class*="paywall"]', '[id*="paywall"]',
        '[class*="subscribe"]', '[id*="subscribe"]',
        '[class*="newsletter"]', '[id*="newsletter"]',
        '[class*="signup"]', '[id*="signup"]',
        '[class*="interstitial"]', '[id*="interstitial"]'
      ];
      overlaySelectors.forEach(function(s) {
        document.querySelectorAll(s).forEach(function(el) {
          el.style.display = 'none';
        });
      });

      // 4. Ukryj fixed/sticky elementy (paski na górze/dole)
      document.querySelectorAll('*').forEach(function(el) {
        var cs = window.getComputedStyle(el);
        if ((cs.position === 'fixed' || cs.position === 'sticky') && cs.zIndex > 100) {
          el.style.display = 'none';
        }
      });

      // 5. Usuń wszystkie iframe (reklamy, social widgets)
      document.querySelectorAll('iframe').forEach(function(el) {
        el.remove();
      });

      // 6. Wyczyść tło i ustaw czytelny styl
      document.body.style.backgroundColor = '#FFFFFF';
      document.body.style.color = '#1a1a1a';
      document.body.style.fontSize = '18px';
      document.body.style.lineHeight = '1.7';
      document.body.style.padding = '16px';
      document.body.style.maxWidth = '100%';
      document.body.style.margin = '0 auto';
      document.body.style.wordWrap = 'break-word';

      // 7. Zwiększ rozmiar czcionki w akapitach
      document.querySelectorAll('p, li, td, th, span').forEach(function(el) {
        el.style.fontSize = '18px';
        el.style.lineHeight = '1.7';
      });

      // 8. Usuń nawigację, stopkę, header
      document.querySelectorAll('nav, footer, [role="navigation"], [role="banner"], [role="contentinfo"]').forEach(function(el) {
        el.style.display = 'none';
      });

      // 9. Usuń boczne paski i sidebary
      document.querySelectorAll('[class*="sidebar"], [id*="sidebar"], [class*="side-bar"], aside').forEach(function(el) {
        el.style.display = 'none';
      });

      // 10. Zamknij otwarte banery kliknięciem escape
      document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', keyCode: 27, bubbles: true}));
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          // Zawsze ukrywaj banery cookie
          _controller.runJavaScript(_hideCookieBanners);
          // Full reader mode tylko dla artykułów
          if (widget.useReaderMode) {
            _injectReaderCss();
          }
          if (mounted) setState(() => _isLoading = false);
        },
        onUrlChange: (change) {
          _currentUrl = change.url;
        },
        onWebResourceError: (error) {
          debugPrint('WebView error: ${error.description}');
          if (mounted) setState(() => _isLoading = false);
        },
      ));

    _loadUrl();
  }

  Future<void> _loadUrl() async {
    try {
      await _controller.loadRequest(Uri.parse(widget.url));
    } catch (e) {
      debugPrint('WebView load error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie udało się załadować strony')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _injectReaderCss() {
    _controller.runJavaScript(_readerCss);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accentFor(context),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final url = _currentUrl ?? widget.url;
              Share.share('${widget.title}\n\n$url');
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              final url = _currentUrl ?? widget.url;
              final nav = Navigator.of(context);
              final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              if (launched && mounted) nav.pop();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: AppTheme.accentFor(context)),
            ),
        ],
      ),
    );
  }
}
