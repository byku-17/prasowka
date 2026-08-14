import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Shared HTTP client with connection pooling, retries, and timeouts.
class HttpClient {
  HttpClient._();
  static final HttpClient _instance = HttpClient._();
  static HttpClient get instance => _instance;

  http.Client? _client;

  void init() {
    if (_client != null) return;
    _client = http.Client();
  }

  void _ensureInitialized() {
    _client ??= http.Client();
  }

  void dispose() {
    _client?.close();
    _client = null;
  }

  /// GET with retry and exponential backoff.
  Future<http.Response?> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
  }) async {
    _ensureInitialized();
    final client = _client!;
    int attempt = 0;
    while (true) {
      try {
        final response = await client.get(uri, headers: headers).timeout(timeout);
        
        // Retry on server errors (5xx) or timeout
        if (response.statusCode >= 500 || response.statusCode == 429) {
          if (attempt < maxRetries) {
            await _delay(attempt, baseDelay);
            attempt++;
            continue;
          }
        }
        return response;
      } on TimeoutException {
        if (attempt < maxRetries) {
          await _delay(attempt, baseDelay);
          attempt++;
          continue;
        }
        debugPrint('HttpClient: Timeout after $maxRetries retries for $uri');
        return null;
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          await _delay(attempt, baseDelay);
          attempt++;
          continue;
        }
        debugPrint('HttpClient: SocketException after $maxRetries retries for $uri: $e');
        return null;
      } catch (e) {
        debugPrint('HttpClient: Unexpected error for $uri: $e');
        return null;
      }
    }
  }

  Future<http.Response?> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    Duration timeout = const Duration(seconds: 15),
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
  }) async {
    _ensureInitialized();
    final client = _client!;
    int attempt = 0;
    while (true) {
      try {
        final response = await client.post(uri, headers: headers, body: body, encoding: encoding).timeout(timeout);
        
        if (response.statusCode >= 500 || response.statusCode == 429) {
          if (attempt < maxRetries) {
            await _delay(attempt, baseDelay);
            attempt++;
            continue;
          }
        }
        return response;
      } on TimeoutException {
        if (attempt < maxRetries) {
          await _delay(attempt, baseDelay);
          attempt++;
          continue;
        }
        debugPrint('HttpClient: Timeout after $maxRetries retries for $uri');
        return null;
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          await _delay(attempt, baseDelay);
          attempt++;
          continue;
        }
        debugPrint('HttpClient: SocketException after $maxRetries retries for $uri: $e');
        return null;
      } catch (e) {
        debugPrint('HttpClient: Unexpected error for $uri: $e');
        return null;
      }
    }
  }

  Future<void> _delay(int attempt, Duration baseDelay) async {
    final delay = baseDelay * (1 << attempt); // exponential backoff
    await Future.delayed(delay);
  }
}