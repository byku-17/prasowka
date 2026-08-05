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
                Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.5), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Błąd danych — dotknij, aby ponowić',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final timeAgo = _getTimeAgo();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // Weather tile (expandable)
          Expanded(
            child: _ExpandableWeatherTile(
              data: _weatherData,
              timeAgo: timeAgo,
              onTap: _openWeatherDetail,
            ),
          ),
          const SizedBox(width: 8),
          // Air quality tile (expandable)
          Expanded(
            child: _ExpandableAirTile(
              data: _airData,
              timeAgo: timeAgo,
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
    // Prostszy format Airly - mapa z współrzędnymi
    final url = 'https://airly.org/map/${coords.latitude.toStringAsFixed(4)},${coords.longitude.toStringAsFixed(4)}';
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

class _ExpandableWeatherTile extends StatefulWidget {
  final WeatherData? data;
  final String timeAgo;
  final VoidCallback onTap;

  const _ExpandableWeatherTile({
    required this.data,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  State<_ExpandableWeatherTile> createState() => _ExpandableWeatherTileState();
}

class _ExpandableWeatherTileState extends State<_ExpandableWeatherTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(_expanded ? 16 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryNavy, AppTheme.primaryNavy.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row (always visible)
            Row(
              children: [
                const Icon(Icons.thermostat, color: AppTheme.accentGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data != null ? '${data.temperature.round()}°C' : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data?.condition ?? 'Brak danych',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Timestamp + expand indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.timeAgo.isNotEmpty)
                      Text(
                        'akt. ${widget.timeAgo}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data != null) ...[
                      Text(
                        '💨 Wiatr: ${data.windSpeed.round()} km/h  💧 Wilgotność: ${data.humidity}%',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Szczegóły na Windy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentGold,
                          side: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableAirTile extends StatefulWidget {
  final AirQualityData? data;
  final String timeAgo;
  final VoidCallback onTap;

  const _ExpandableAirTile({
    required this.data,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  State<_ExpandableAirTile> createState() => _ExpandableAirTileState();
}

class _ExpandableAirTileState extends State<_ExpandableAirTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final color = data == null
        ? Colors.grey
        : data.pm25 <= 10
            ? Colors.green
            : data.pm25 <= 25
                ? Colors.orange
                : Colors.red;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(_expanded ? 16 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row (always visible)
            Row(
              children: [
                const Icon(Icons.air, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data != null ? 'PM2.5: ${data.pm25.round()}' : '—',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        data?.level ?? 'Brak danych',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Timestamp + expand indicator
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.timeAgo.isNotEmpty)
                      Text(
                        'akt. ${widget.timeAgo}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
                      ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Expanded content
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data != null) ...[
                      Text(
                        'PM10: ${data.pm10.round()}  O₃: ${data.o3.round()}  NO₂: ${data.no2.round()}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Szczegóły na Airly'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
        ),
      ),
    );
  }
}
