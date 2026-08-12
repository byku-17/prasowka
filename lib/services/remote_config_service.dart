import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _config;
  bool _initialized = false;

  Future<void> init() async {
    try {
      _config = FirebaseRemoteConfig.instance;

      await _config!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _config!.setDefaults(const {
        'sportdb_api_key': '',
        'thesportsdb_api_key': '',
        'newsapi_key': '',
        'newsapi_domains': '',
        'top_sports_competitions': 'premier league,ekstraklasa,la liga,laliga,serie a,bundesliga,ligue 1,champions league,europa league,liga mistrzów,liga europy,eredivisie,liga portugal,primeira liga,super lig,superliga,nba,euroleague,euroliga,plk,nhl,shl,liiga,nfl,mlb,super bowl,atp,wta,wimbledon,roland garros,us open,australian open,formula 1,formula1,f1,plusliga,plus liga',
        'translation_enabled': true,
      });

      try {
        await _config!.fetchAndActivate();
        debugPrint('RemoteConfig: fetched successfully');
      } catch (e) {
        debugPrint('RemoteConfig: fetch failed, using defaults ($e)');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('RemoteConfig: init failed completely ($e)');
      _initialized = false;
    }
  }

  bool get isInitialized => _initialized && _config != null;

  String _get(String key, {String? fallback}) {
    if (_config == null) {
      if (kDebugMode) {
        try { return dotenv.env[key] ?? ''; } catch (_) {}
      }
      return fallback ?? '';
    }
    try {
      final remote = _config!.getString(key);
      if (remote.isNotEmpty) return remote;
    } catch (_) {}
    if (fallback != null && fallback.isNotEmpty) return fallback;
    if (kDebugMode) {
      try { return dotenv.env[key] ?? ''; } catch (_) {}
    }
    return '';
  }

  String get sportDbKey => _get('sportdb_api_key');
  String get theSportsDbKey => _get('thesportsdb_api_key');
  String get newsApiKey => _get('newsapi_key');
  String get newsApiDomains => _get('newsapi_domains');
  String get topSportsCompetitions => _get('top_sports_competitions');
  bool get translationEnabled {
    if (_config == null) return true;
    try {
      return _config!.getBool('translation_enabled');
    } catch (_) {
      return true;
    }
  }
}
