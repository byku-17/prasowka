import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CityCoordinates {
  final String name;
  final double latitude;
  final double longitude;

  const CityCoordinates({required this.name, required this.latitude, required this.longitude});

  static const warszawa = CityCoordinates(name: 'Warszawa', latitude: 52.2297, longitude: 21.0122);
}

class WeatherData {
  final double temperature;
  final double windSpeed;
  final int humidity;
  final String condition;

  const WeatherData({
    required this.temperature,
    required this.windSpeed,
    required this.humidity,
    required this.condition,
  });
}

class AirQualityData {
  final double pm25;
  final double pm10;
  final double no2;
  final double o3;
  final String level;

  const AirQualityData({
    required this.pm25,
    required this.pm10,
    required this.no2,
    required this.o3,
    required this.level,
  });
}

class WeatherService {
  static const String _weatherBase = 'https://api.open-meteo.com/v1/forecast';
  static const String _airBase = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _geoBase = 'https://geocoding-api.open-meteo.com/v1/search';

  Future<WeatherData?> fetchWeather(CityCoordinates city) async {
    try {
      final url = '$_weatherBase?latitude=${city.latitude}&longitude=${city.longitude}&current=temperature_2m,wind_speed_10m,relative_humidity_2m,weather_code';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        return WeatherData(
          temperature: (current['temperature_2m'] ?? 0).toDouble(),
          windSpeed: (current['wind_speed_10m'] ?? 0).toDouble(),
          humidity: (current['relative_humidity_2m'] ?? 0).toInt(),
          condition: _mapWeatherCode(current['weather_code']),
        );
      }
    } catch (e) {
      debugPrint('Sowa Weather: Błąd pogody: $e');
    }
    return null;
  }

  Future<AirQualityData?> fetchAirQuality(CityCoordinates city) async {
    try {
      final url = '$_airBase?latitude=${city.latitude}&longitude=${city.longitude}&current=pm2_5,pm10,nitrogen_dioxide,ozone';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'];
        final pm25 = (current['pm2_5'] ?? 0).toDouble();
        return AirQualityData(
          pm25: pm25,
          pm10: (current['pm10'] ?? 0).toDouble(),
          no2: (current['nitrogen_dioxide'] ?? 0).toDouble(),
          o3: (current['ozone'] ?? 0).toDouble(),
          level: _aqiLevel(pm25),
        );
      }
    } catch (e) {
      debugPrint('Sowa Weather: Błąd jakości powietrza: $e');
    }
    return null;
  }

  String _mapWeatherCode(int? code) {
    switch (code) {
      case 0: return 'Słonecznie';
      case 1: case 2: case 3: return 'Pochmurno';
      case 45: case 48: return 'Mgła';
      case 51: case 53: case 55: return 'Mżawka';
      case 61: case 63: case 65: return 'Deszcz';
      case 71: case 73: case 75: return 'Śnieg';
      case 80: case 81: case 82: return 'Burze';
      case 95: case 96: case 99: return 'Burza';
      default: return '—';
    }
  }

  String _aqiLevel(double pm25) {
    if (pm25 <= 10) return 'Dobre';
    if (pm25 <= 25) return 'Umiarkowane';
    if (pm25 <= 50) return 'Złe';
    return 'Bardzo złe';
  }
}
