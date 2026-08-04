import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/services/weather_service.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_webview_screen.dart';
import 'package:prasowka/theme/app_theme.dart';

class LocalInfoBar extends StatefulWidget {
  const LocalInfoBar({super.key});

  @override
  State<LocalInfoBar> createState() => _LocalInfoBarState();
}

class _LocalInfoBarState extends State<LocalInfoBar> {
  final WeatherService _weather = WeatherService();
  WeatherData? _weatherData;
  AirQualityData? _airData;
  bool _isLoading = true;
  bool _hasError = false;
  String? _lastCityHash;

  @override
  void initState() {
    super.initState();
    // Inicjalne pobranie danych
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndFetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndFetch();
  }

  void _checkAndFetch() {
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    
    if (_lastCityHash != cityHash) {
      _lastCityHash = cityHash;
      _fetchData(settings.cityCoordinates);
    }
  }

  Future<void> _fetchData(CityCoordinates city) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        _weather.fetchWeather(city),
        _weather.fetchAirQuality(city)
      ]).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _weatherData = results[0] as WeatherData?;
          _airData = results[1] as AirQualityData?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Sowa LocalInfoBar Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Słuchamy zmian w SettingsProvider, aby wyzwalać didChangeDependencies
    context.watch<SettingsProvider>();

    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_hasError) {
      return SizedBox(
        height: 60,
        child: Center(
          child: GestureDetector(
            onTap: _retryFetch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.5), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Błąd danych pogodowych — dotknij, aby ponowić',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildWeatherTile()),
          const SizedBox(width: 12),
          Expanded(child: _buildAirTile()),
        ],
      ),
    );
  }

  void _retryFetch() {
    _lastCityHash = null;
    _checkAndFetch();
  }

  Widget _buildWeatherTile() {
    final data = _weatherData;
    final city = context.read<SettingsProvider>().preferredCity;
    final slug = _getCitySlug(city, isWeather: true);
    final url = 'https://pogoda.onet.pl/prognoza-pogody/$slug';

    return GestureDetector(
      onTap: () => _openInternalBrowser(url, 'Pogoda: $city'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.thermostat, color: AppTheme.accentGold, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data != null ? '${data.temperature.round()}°C' : '—',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data?.condition ?? 'Brak danych',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (data != null)
                    Text(
                      '💨 ${data.windSpeed.round()} km/h  💧${data.humidity}%',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10),
                    ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.4), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAirTile() {
    final data = _airData;
    final city = context.read<SettingsProvider>().preferredCity;
    final slug = _getCitySlug(city, isWeather: false);
    final url = 'https://aqicn.org/city/poland/$slug';

    final color = data == null
        ? Colors.grey
        : data.pm25 <= 10
            ? Colors.green
            : data.pm25 <= 25
                ? Colors.orange
                : Colors.red;

    return GestureDetector(
      onTap: () => _openInternalBrowser(url, 'Jakość powietrza: $city'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.air, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data != null ? 'PM2.5: ${data.pm25.round()}' : '—',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    data?.level ?? 'Brak danych',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                  ),
                  if (data != null)
                    Text(
                      'PM10: ${data.pm10.round()}  O₃: ${data.o3.round()}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                    ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, color: Colors.white.withValues(alpha: 0.4), size: 14),
          ],
        ),
      ),
    );
  }

  void _openInternalBrowser(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleWebViewScreen(url: url, title: title),
      ),
    );
  }

  String _getCitySlug(String city, {required bool isWeather}) {
    final lower = city.toLowerCase();
    
    // Specyficzne mapowania dla AQICN (często nazwy angielskie)
    if (!isWeather) {
      if (lower == 'warszawa') return 'warsaw';
      if (lower == 'kraków') return 'krakow';
      if (lower == 'wrocław') return 'wroclaw';
      if (lower == 'gdańsk') return 'gdansk';
      if (lower == 'poznań') return 'poznan';
      if (lower == 'łódź') return 'lodz';
      if (lower == 'katowice') return 'katowice';
    }

    // Standardowe usuwanie ogonków dla Onet Pogoda
    var slug = lower;
    const polish = 'ąćęłńóśźż';
    const latin = 'acelnoszz';
    for (int i = 0; i < polish.length; i++) {
      slug = slug.replaceAll(polish[i], latin[i]);
    }
    return slug;
  }
}
