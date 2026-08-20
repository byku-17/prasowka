import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManager {
  static const _key = 'appImageCache_v1';
  static final CacheManager _instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
    ),
  );

  static CacheManager get instance => _instance;
}
