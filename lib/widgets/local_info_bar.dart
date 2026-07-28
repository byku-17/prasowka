import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prasowka/services/weather_service.dart';
import 'package:prasowka/providers/settings_provider.dart';
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
  String? _lastCityHash;

  void _checkAndFetch() {
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    if (_lastCityHash != cityHash) {
      _lastCityHash = cityHash;
      _fetchData(settings.cityCoordinates);
    }
  }

  Future<void> _fetchData(CityCoordinates city) async {
    setState(() => _isLoading = true);
    final results = await Future.wait([_weather.fetchWeather(city), _weather.fetchAirQuality(city)]);
    if (mounted) {
      setState(() {
        _weatherData = results[0] as WeatherData?;
        _airData = results[1] as AirQualityData?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();
    _checkAndFetch();

    if (_isLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse('https://www.google.com/search?q=jakość+powietrza+$city'), mode: LaunchMode.externalApplication),
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
