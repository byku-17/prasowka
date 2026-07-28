import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prasowka/services/weather_service.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/theme/app_theme.dart';

/// Mapowanie miast → oficjalne strony stacji powietrza GIOS
const Map<String, String> _airQualityUrls = {
  'Warszawa': 'https://powietrze.gios.gov.pl/pjp/current/station/64',
  'Kraków': 'https://powietrze.gios.gov.pl/pjp/current/station/117',
  'Wrocław': 'https://powietrze.gios.gov.pl/pjp/current/station/102',
  'Gdańsk': 'https://powietrze.gios.gov.pl/pjp/current/station/83',
  'Poznań': 'https://powietrze.gios.gov.pl/pjp/current/station/92',
  'Łódź': 'https://powietrze.gios.gov.pl/pjp/current/station/86',
  'Katowice': 'https://powietrze.gios.gov.pl/pjp/current/station/108',
};

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

  void _checkAndFetch() {
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    if (_lastCityHash != cityHash) {
      _lastCityHash = cityHash;
      _fetchData(settings.cityCoordinates);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAndFetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndFetch();
  }

  Future<void> _fetchData(CityCoordinates city) async {
    if (!mounted) return;
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final results = await Future.wait(
        [_weather.fetchWeather(city), _weather.fetchAirQuality(city)],
      ).timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _weatherData = results[0] as WeatherData?;
          _airData = results[1] as AirQualityData?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('LocalInfoBar fetch error: $e');
      if (mounted) {
        setState(() { _isLoading = false; _hasError = true; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utwórz dependencję na SettingsProvider, aby didChangeDependencies
    // było wywoływane przy zmianie miasta
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
                Icon(Icons.wifi_off, color: Colors.white.withValues(alpha: 0.5), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Brak danych pogodowych — dotknij, aby spróbować ponownie',
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
    final settings = context.read<SettingsProvider>();
    _lastCityHash = null;
    _fetchData(settings.cityCoordinates);
  }

  Widget _buildWeatherTile() {
    final data = _weatherData;
    final city = context.read<SettingsProvider>().preferredCity;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://www.google.com/search?q=pogoda+$city'), mode: LaunchMode.externalApplication),
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
    final color = data == null
        ? Colors.grey
        : data.pm25 <= 10
            ? Colors.green
            : data.pm25 <= 25
                ? Colors.orange
                : Colors.red;

    final airUrl = _airQualityUrls[city]
        ?? 'https://www.google.com/search?q=jakość+powietrza+$city';

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(airUrl), mode: LaunchMode.externalApplication),
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
}
