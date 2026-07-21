/// Reprezentuje źródło informacji (np. kanał RSS konkretnego portalu).
class NewsSource {
  final String id;
  final String name;
  final String rssUrl;
  final String? logoUrl;
  final String categoryId;

  const NewsSource({
    required this.id,
    required this.name,
    required this.rssUrl,
    required this.categoryId,
    this.logoUrl,
  });

  /// Kompletna lista źródeł RSS dla aplikacji Prasówka
  static List<NewsSource> get defaultSources => [
    // --- POLSKA ---
    const NewsSource(id: 'rmf24_polska', name: 'RMF24', rssUrl: 'https://www.rmf24.pl/fakty/polska/feed', categoryId: 'poland'),
    const NewsSource(id: 'tvn24_najwazniejsze', name: 'TVN24', rssUrl: 'https://tvn24.pl/najwazniejsze.xml', categoryId: 'poland'),
    const NewsSource(id: 'onet_wiadomosci', name: 'Onet', rssUrl: 'https://wiadomosci.onet.pl/.feed', categoryId: 'poland'),
    const NewsSource(id: 'rp_polska', name: 'Rzeczpospolita', rssUrl: 'https://www.rp.pl/rss/1016', categoryId: 'poland'),
    const NewsSource(id: 'interia_fakty', name: 'Interia Fakty', rssUrl: 'https://fakty.interia.pl/feed', categoryId: 'poland'),
    const NewsSource(id: 'gazeta_pl_wiadomosci', name: 'Gazeta.pl', rssUrl: 'http://wiadomosci.gazeta.pl/pub/rss/wiadomosci.xml', categoryId: 'poland'),

    // --- ŚWIAT ---
    const NewsSource(id: 'bbc_world', name: 'BBC News', rssUrl: 'http://feeds.bbci.co.uk/news/world/rss.xml', categoryId: 'world'),
    const NewsSource(id: 'nyt_world', name: 'New York Times', rssUrl: 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml', categoryId: 'world'),
    const NewsSource(id: 'guardian_world', name: 'The Guardian', rssUrl: 'https://www.theguardian.com/world/rss', categoryId: 'world'),
    const NewsSource(id: 'aljazeera_world', name: 'Al Jazeera', rssUrl: 'https://www.aljazeera.com/xml/rss/all.xml', categoryId: 'world'),
    const NewsSource(id: 'reuters_world', name: 'Reuters', rssUrl: 'https://www.reutersagency.com/feed/', categoryId: 'world'),

    // --- BIZNES ---
    const NewsSource(id: 'money_pl', name: 'Money.pl', rssUrl: 'https://www.money.pl/rss/', categoryId: 'business'),
    const NewsSource(id: 'business_insider_pl', name: 'Business Insider PL', rssUrl: 'https://businessinsider.com.pl/.feed', categoryId: 'business'),
    const NewsSource(id: 'bankier_pl', name: 'Bankier.pl', rssUrl: 'https://www.bankier.pl/rss/wiadomosci.xml', categoryId: 'business'),
    const NewsSource(id: 'pb_pl', name: 'Puls Biznesu', rssUrl: 'https://www.pb.pl/rss', categoryId: 'business'),
    const NewsSource(id: 'rp_ekonomia', name: 'Rzeczpospolita Ekonomia', rssUrl: 'https://www.rp.pl/rss/ekonomia', categoryId: 'business'),
    const NewsSource(id: 'gazetaprawna_pl', name: 'Dziennik Gazeta Prawna', rssUrl: 'http://rss.gazetaprawna.pl/GazetaPrawna', categoryId: 'business'),
    const NewsSource(id: 'parkiet_com', name: 'Parkiet.com', rssUrl: 'https://www.parkiet.com/rss.xml', categoryId: 'business'),
    const NewsSource(id: 'interia_biznes', name: 'Interia Biznes', rssUrl: 'http://kanaly.rss.interia.pl/biznes.xml', categoryId: 'business'),
    const NewsSource(id: 'forsal_pl', name: 'Forsal.pl', rssUrl: 'http://rss.forsal.pl/Forsal', categoryId: 'business'),
    const NewsSource(id: 'wnp_pl', name: 'WNP.pl (Przemysł)', rssUrl: 'https://www.wnp.pl/rss/serwis_rss_999.xml', categoryId: 'business'),
    const NewsSource(id: 'next_gazeta_pl', name: 'Next.gazeta.pl', rssUrl: 'http://rss.gazeta.pl/pub/rss/next.xml', categoryId: 'business'),
    const NewsSource(id: 'subiektywnie_o_finansach', name: 'Subiektywnie o Finansach', rssUrl: 'https://subiektywnieofinansach.pl/feed/', categoryId: 'business'),
    const NewsSource(id: 'bnbn_pl', name: 'BNBN.pl', rssUrl: 'https://bnbn.pl/feed/', categoryId: 'business'),
    const NewsSource(id: 'infor_pl', name: 'Infor.pl', rssUrl: 'https://www.infor.pl/rss/aktualnosci_prawno_gospodarcze.xml', categoryId: 'business'),
    const NewsSource(id: 'forbes_pl', name: 'Forbes Polska', rssUrl: 'https://news.google.com/rss/search?q=site:forbes.pl&hl=pl&gl=PL&ceid=PL:pl', categoryId: 'business'),
    const NewsSource(id: 'reuters_business', name: 'Reuters Business', rssUrl: 'https://openrss.org/www.reuters.com/business', categoryId: 'business'),
    const NewsSource(id: 'wsj_business', name: 'Wall Street Journal', rssUrl: 'https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml', categoryId: 'business'),
    const NewsSource(id: 'cnbc_business', name: 'CNBC Business', rssUrl: 'https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=10001147', categoryId: 'business'),

    // --- TECH & AI ---
    const NewsSource(id: 'sztuczna_inteligencja_pl', name: 'Sztuczna-Inteligencja.pl', rssUrl: 'https://www.sztucznainteligencja.org.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'aiot_pl', name: 'AIoT.pl', rssUrl: 'https://aiot.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'ai_pl', name: 'AI.pl', rssUrl: 'https://ai.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'genai_works', name: 'GenAI Works', rssUrl: 'https://medium.com/feed/generative-ai', categoryId: 'tech'),
    const NewsSource(id: 'warsaw_ai', name: 'Warsaw.AI News', rssUrl: 'https://warsawai.substack.com/feed', categoryId: 'tech'),
    const NewsSource(id: 'antyweb', name: 'Antyweb', rssUrl: 'https://antyweb.pl/feed', categoryId: 'tech'),
    const NewsSource(id: 'spiders_web', name: "Spider's Web", rssUrl: 'https://spidersweb.pl/feed', categoryId: 'tech'),
    const NewsSource(id: 'purepc', name: 'PurePC', rssUrl: 'https://www.purepc.pl/rss', categoryId: 'tech'),
    const NewsSource(id: 'benchmark_pl', name: 'Benchmark.pl', rssUrl: 'http://www.benchmark.pl/rss/benchmark-pl.xml', categoryId: 'tech'),
    const NewsSource(id: 'komputer_swiat', name: 'Komputer Świat', rssUrl: 'https://www.komputerswiat.pl/rss.xml', categoryId: 'tech'),
    const NewsSource(id: 'innpoland', name: 'INNPoland.pl', rssUrl: 'https://innpoland.pl/rss', categoryId: 'tech'),
    const NewsSource(id: 'mamstartup', name: 'MamStartup', rssUrl: 'https://mamstartup.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'mambiznes', name: 'Mambiznes.pl', rssUrl: 'https://mambiznes.pl/rss', categoryId: 'tech'),
    const NewsSource(id: 'just_geek_it', name: 'Just Geek IT', rssUrl: 'https://geek.justjoin.it/feed', categoryId: 'tech'),
    const NewsSource(id: 'itwiz', name: 'ITwiz', rssUrl: 'https://itwiz.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'brandsit', name: 'Brandsit.pl', rssUrl: 'https://brandsit.pl/feed/', categoryId: 'tech'),
    const NewsSource(id: 'techcrunch', name: 'TechCrunch', rssUrl: 'https://techcrunch.com/feed/', categoryId: 'tech'),
    const NewsSource(id: 'the_verge', name: 'The Verge', rssUrl: 'https://www.theverge.com/rss/index.xml', categoryId: 'tech'),

    // --- SPORT ---
    const NewsSource(id: 'probasket', name: 'Probasket', rssUrl: 'https://probasket.pl/feed/', categoryId: 'sport'),
    const NewsSource(id: 'gwiazdy_basketu', name: 'Gwiazdy Basketu', rssUrl: 'https://gwiazdybasketu.pl/feed/', categoryId: 'sport'),
    const NewsSource(id: 'szosty_gracz', name: 'Szósty Gracz', rssUrl: 'https://szostygracz.pl/feed/', categoryId: 'sport'),
    const NewsSource(id: 'zkrainynba', name: 'Z Krainy NBA', rssUrl: 'https://zkrainynba.com/feed/', categoryId: 'sport'),
    const NewsSource(id: 'rzutza3', name: 'RzutZa3', rssUrl: 'https://rzutza3.pl/feed/', categoryId: 'sport'),
    const NewsSource(id: 'tvp_sport', name: 'TVP Sport', rssUrl: 'http://www.tvp.pl/rss.php?id=12', categoryId: 'sport'),
    const NewsSource(id: 'polsat_sport', name: 'Polsat Sport', rssUrl: 'https://www.polsatsport.pl/rss/wszystkie.xml', categoryId: 'sport'),
    const NewsSource(id: 'weszlo', name: 'Weszło', rssUrl: 'https://weszlo.com/feed/', categoryId: 'sport'),
    const NewsSource(id: 'transfery_info', name: 'Transfery.info', rssUrl: 'https://transfery.info/rss', categoryId: 'sport'),
    const NewsSource(id: 'sportowefakty', name: 'WP SportoweFakty', rssUrl: 'https://sportowefakty.wp.pl/rss.xml', categoryId: 'sport'),
    const NewsSource(id: 'eurosport_pl', name: 'Eurosport PL', rssUrl: 'https://tvn24.pl/sport,4.xml', categoryId: 'sport'),
    const NewsSource(id: 'sky_sports_pl', name: 'Sky Sports PL', rssUrl: 'https://www.skysports.com/rss/11661', categoryId: 'sport'),
    const NewsSource(id: 'f1_official', name: 'Formula 1', rssUrl: 'https://www.formula1.com/en/latest/all.xml', categoryId: 'sport'),
    const NewsSource(id: 'motogp_crash', name: 'MotoGP (Crash)', rssUrl: 'https://www.crash.net/rss/motogp', categoryId: 'sport'),
    const NewsSource(id: 'wrc_dirtfish', name: 'WRC (DirtFish)', rssUrl: 'https://dirtfish.com/rally/wrc/feed/', categoryId: 'sport'),
    const NewsSource(id: 'naszosie_pl', name: 'Naszosie.pl', rssUrl: 'https://naszosie.pl/feed/', categoryId: 'sport'),
    const NewsSource(id: 'rowery_org', name: 'Rowery.org', rssUrl: 'https://rowery.org/feed/', categoryId: 'sport'),
    const NewsSource(id: 'cyclingnews', name: 'Cyclingnews', rssUrl: 'https://www.cyclingnews.com/rss', categoryId: 'sport'),
    const NewsSource(id: 'gravel_cyclist', name: 'Gravel Cyclist', rssUrl: 'https://www.gravelcyclist.com/feed/', categoryId: 'sport'),
    const NewsSource(id: 'siatka_org', name: 'Siatka.org', rssUrl: 'https://siatka.org/feed/', categoryId: 'sport'),
    const NewsSource(id: 'tennis_x', name: 'Tennis-X', rssUrl: 'http://feeds.feedburner.com/tennisx', categoryId: 'sport'),

    // --- NAUKA ---
    const NewsSource(id: 'nature_news', name: 'Nature', rssUrl: 'http://feeds.nature.com/nature/rss/news', categoryId: 'science'),
    const NewsSource(id: 'science_news', name: 'Science', rssUrl: 'https://www.science.org/rss/news_current.xml', categoryId: 'science'),
    const NewsSource(id: 'plos_one', name: 'PLOS ONE', rssUrl: 'https://journals.plos.org/plosone/feed/rss', categoryId: 'science'),
    const NewsSource(id: 'sci_american', name: 'Scientific American', rssUrl: 'http://rss.sciam.com/ScientificAmerican-Global', categoryId: 'science'),
    const NewsSource(id: 'nasa_news', name: 'NASA News', rssUrl: 'https://www.nasa.gov/news-release/feed/', categoryId: 'science'),
    const NewsSource(id: 'phys_org', name: 'Phys.org', rssUrl: 'https://phys.org/rss-feed/', categoryId: 'science'),
    const NewsSource(id: 'nejm_news', name: 'NEJM', rssUrl: 'https://www.nejm.org/rss-feed/', categoryId: 'science'),
    const NewsSource(id: 'the_lancet', name: 'The Lancet', rssUrl: 'https://www.thelancet.com/rssfeed/lancet.xml', categoryId: 'science'),
    const NewsSource(id: 'jama_news', name: 'JAMA', rssUrl: 'https://jamanetwork.com/rss/site_3.xml', categoryId: 'science'),
    const NewsSource(id: 'bmj_news', name: 'BMJ', rssUrl: 'https://www.bmj.com/rss/recent.xml', categoryId: 'science'),
    const NewsSource(id: 'puls_medycyny', name: 'Puls Medycyny', rssUrl: 'https://pulsmedycyny.pl/rss', categoryId: 'science'),
    const NewsSource(id: 'nauka_w_polsce', name: 'Nauka w Polsce', rssUrl: 'https://naukawpolsce.pl/all/rss.xml', categoryId: 'science'),
    const NewsSource(id: 'kwantowo_pl', name: 'Kwantowo.pl', rssUrl: 'https://www.kwantowo.pl/feed/', categoryId: 'science'),
    const NewsSource(id: 'projekt_pulsar', name: 'Projekt Pulsar', rssUrl: 'https://www.polityka.pl/rss/articles.xml?list=268', categoryId: 'science'),
    const NewsSource(id: 'dziennik_naukowy', name: 'Dziennik Naukowy', rssUrl: 'https://dzienniknaukowy.pl/feed/', categoryId: 'science'),

    // --- MOTORYZACJA ---
    const NewsSource(id: 'autocentrum', name: 'Autocentrum.pl', rssUrl: 'https://www.autocentrum.pl/rss/newsy.xml', categoryId: 'automotive'),
    const NewsSource(id: 'autokult', name: 'WP Autokult', rssUrl: 'https://autokult.pl/rss/wszystkie', categoryId: 'automotive'),
    const NewsSource(id: 'onet_moto', name: 'Onet Moto', rssUrl: 'https://wiadomosci.onet.pl/moto/.feed', categoryId: 'automotive'),
    const NewsSource(id: 'moto_pl', name: 'Moto.pl', rssUrl: 'http://wiadomosci.gazeta.pl/pub/rss/moto.xml', categoryId: 'automotive'),
    const NewsSource(id: 'interia_moto', name: 'Interia Motoryzacja', rssUrl: 'http://kanaly.rss.interia.pl/motoryzacja.xml', categoryId: 'automotive'),
    const NewsSource(id: 'auto_swiat', name: 'Auto Świat', rssUrl: 'https://www.auto-swiat.pl/rss', categoryId: 'automotive'),
    const NewsSource(id: 'magazyn_auto', name: 'Magazyn Auto (Motor)', rssUrl: 'https://rss.interia.pl/magazynauto.xml', categoryId: 'automotive'),
    const NewsSource(id: 'top_gear_global', name: 'Top Gear (Global)', rssUrl: 'https://www.topgear.com/rss', categoryId: 'automotive'),
    const NewsSource(id: 'automobilista', name: 'Automobilista', rssUrl: 'https://automobilista.com.pl/feed/', categoryId: 'automotive'),
    const NewsSource(id: 'elektrowoz', name: 'Elektrowóz', rssUrl: 'https://elektrowoz.pl/feed/', categoryId: 'automotive'),
    const NewsSource(id: 'autoblog_pl', name: "Spider's Web Autoblog", rssUrl: 'https://spidersweb.pl/autoblog/feed', categoryId: 'automotive'),
    const NewsSource(id: 'green_car_congress', name: 'Green Car Congress', rssUrl: 'https://www.greencarcongress.com/rss.xml', categoryId: 'automotive'),
    const NewsSource(id: 'samar_pl', name: 'IBRM Samar', rssUrl: 'https://news.google.com/rss/search?q=site:samar.pl&hl=pl&gl=PL&ceid=PL:pl', categoryId: 'automotive'),
    const NewsSource(id: 'wrc_moto', name: 'WRC.net.pl', rssUrl: 'https://wrc.net.pl/feed/', categoryId: 'automotive'),
    const NewsSource(id: 'sokol_oko_f1', name: 'Sokół Około F1', rssUrl: 'https://sokolimokiem.com/feed/', categoryId: 'automotive'),
  ];
}
