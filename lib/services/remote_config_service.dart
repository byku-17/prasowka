import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late final FirebaseRemoteConfig _config;

  Future<void> init() async {
    _config = FirebaseRemoteConfig.instance;

    await _config.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1),
    ));

    await _config.setDefaults(const {
      'sportdb_api_key': '',
      'thesportsdb_api_key': '',
      'newsapi_key': '',
    });

    try {
      await _config.fetchAndActivate();
      debugPrint('RemoteConfig: fetched successfully');
    } catch (e) {
      debugPrint('RemoteConfig: fetch failed, using defaults ($e)');
    }
  }

  String _get(String key, {String? fallback}) {
    final remote = _config.getString(key);
    if (remote.isNotEmpty) return remote;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return dotenv.env[key] ?? '';
  }

  String get sportDbKey => _get('sportdb_api_key', fallback: dotenv.env['SPORTDB_API_KEY']);
  String get theSportsDbKey => _get('thesportsdb_api_key', fallback: dotenv.env['THESPORTSDB_API_KEY']);
  String get newsApiKey => _get('newsapi_key', fallback: dotenv.env['NEWSAPI_KEY']);
}
