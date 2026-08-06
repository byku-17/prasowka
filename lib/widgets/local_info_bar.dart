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
  DateTime? _lastFetchTime;
  bool _expanded = false;

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

  void _checkAndFetch() {
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    
    if (_lastCityHash != cityHash) {
      debugPrint('Sowa Weather: Zmiana miasta ($cityHash). Pobieram dane...');
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
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('Sowa Weather Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _getTimeAgo() {
    if (_lastFetchTime == null) return '';
    final diff = DateTime.now().difference(_lastFetchTime!);
    if (diff.inMinutes < 1) return 'teraz';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours} h temu';
    return '${diff.inDays} d temu';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<SettingsProvider>();

    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_hasError) {
      return SizedBox(
        height: 50,
        child: Center(
          child: GestureDetector(
            onTap: _retryFetch,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : Colors.grey, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Błąd danych — dotknij, aby ponowić',
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.5) : Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final timeAgo = _getTimeAgo();
    // timeAgo kept for potential future use
    (timeAgo);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weather tile (expandable)
          Expanded(
            child: _ExpandableWeatherTile(
              data: _weatherData,
              expanded: _expanded,
              onExpansionChanged: (v) => setState(() => _expanded = v),
              onTap: _openWeatherDetail,
            ),
          ),
          const SizedBox(width: 6),
          // Air quality tile (expandable)
          Expanded(
            child: _ExpandableAirTile(
              data: _airData,
              expanded: _expanded,
              onExpansionChanged: (v) => setState(() => _expanded = v),
              onTap: _openAirDetail,
            ),
          ),
        ],
      ),
    );
  }

  void _retryFetch() {
    _lastCityHash = null;
    _checkAndFetch();
  }

  void _openWeatherDetail() {
    final settings = context.read<SettingsProvider>();
    final coords = settings.cityCoordinates;
    final city = settings.preferredCity;
    final url = 'https://www.windy.com/?${coords.latitude.toStringAsFixed(4)},${coords.longitude.toStringAsFixed(4)},11';
    _openInternalBrowser(url, 'Pogoda: $city (Windy)');
  }

  void _openAirDetail() {
    final settings = context.read<SettingsProvider>();
    final coords = settings.cityCoordinates;
    final city = settings.preferredCity;
    // Airly mapa z współrzędnymi w hash - działa na mobile
    final url = 'https://airly.org/map#lat=${coords.latitude.toStringAsFixed(4)}&lng=${coords.longitude.toStringAsFixed(4)}&zoom=11';
    _openInternalBrowser(url, 'Jakość powietrza: $city (Airly)');
  }

  void _openInternalBrowser(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleWebViewScreen(
          url: url,
          title: title,
          useReaderMode: false,
        ),
      ),
    );
  }
}

class _ExpandableWeatherTile extends StatelessWidget {
  final WeatherData? data;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onTap;

  const _ExpandableWeatherTile({
    required this.data,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = data; // local copy for null safety
    return GestureDetector(
      onTap: () => onExpansionChanged(!expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(expanded ? 12 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                const Icon(Icons.thermostat, color: AppTheme.accentGold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        w != null ? '${w.temperature.round()}°C' : '—°C',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        w?.condition ?? 'Brak danych',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ],
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (w != null)
                      Text(
                        '💨 ${w.windSpeed.round()} km/h  💧${w.humidity}%',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('Windy', style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentGold,
                          side: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableAirTile extends StatelessWidget {
  final AirQualityData? data;
  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback onTap;

  const _ExpandableAirTile({
    required this.data,
    required this.expanded,
    required this.onExpansionChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = data; // local copy for null safety
    final color = a == null
        ? Colors.grey
        : a.pm25 <= 10
            ? Colors.green
            : a.pm25 <= 25
                ? Colors.orange
                : Colors.red;

    return GestureDetector(
      onTap: () => onExpansionChanged(!expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(expanded ? 12 : 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
            Row(
              children: [
                const Icon(Icons.air, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a != null ? 'PM2.5: ${a.pm25.round()}' : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        a?.level ?? 'Brak danych',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ],
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a != null)
                      Text(
                        'PM10: ${a.pm10.round()}  O₃: ${a.o3.round()}  NO₂: ${a.no2.round()}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(Icons.open_in_new, size: 12),
                        label: const Text('Airly', style: TextStyle(fontSize: 10)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
