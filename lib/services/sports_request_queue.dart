import 'dart:async';
import 'package:flutter/foundation.dart';

class _SourceState {
  DateTime? cooldownUntil;
  int failureCount = 0;

  bool get isOnCooldown {
    if (cooldownUntil == null) return false;
    if (DateTime.now().isAfter(cooldownUntil!)) {
      cooldownUntil = null;
      return false;
    }
    return true;
  }
}

class SportsRequestQueue {
  final int maxConcurrent;
  final Duration minDelay;
  final int maxRetries;
  final Map<String, _SourceState> _sourceStates = {};

  int _running = 0;
  final List<Completer<void>> _waiters = [];

  SportsRequestQueue({
    this.maxConcurrent = 3,
    this.minDelay = const Duration(milliseconds: 500),
    this.maxRetries = 3,
  });

  bool _isOnCooldown(String source) {
    return _sourceStates[source]?.isOnCooldown ?? false;
  }

  void _recordFailure(String source) {
    final state = _sourceStates.putIfAbsent(source, () => _SourceState());
    state.failureCount++;

    final cooldownMinutes = _calculateCooldown(state.failureCount);
    state.cooldownUntil = DateTime.now().add(cooldownMinutes);
    debugPrint('SportsQueue: $source FAIL #${state.failureCount} → cooldown ${cooldownMinutes.inMinutes}min');
  }

  void _recordSuccess(String source) {
    final state = _sourceStates.putIfAbsent(source, () => _SourceState());
    state.failureCount = 0;
    state.cooldownUntil = null;
  }

  Duration _calculateCooldown(int failureCount) {
    switch (failureCount) {
      case 1: return const Duration(seconds: 5);
      case 2: return const Duration(seconds: 15);
      case 3: return const Duration(minutes: 1);
      case 4: return const Duration(minutes: 5);
      default: return const Duration(minutes: 15);
    }
  }

  Future<void> _acquire() async {
    while (_running >= maxConcurrent) {
      final completer = Completer<void>();
      _waiters.add(completer);
      await completer.future;
    }
    _running++;
  }

  void _release() {
    _running--;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }

  Future<T> enqueue<T>(
    Future<T> Function() request, {
    String source = 'unknown',
  }) async {
    if (_isOnCooldown(source)) {
      debugPrint('SportsQueue: $source w cooldownie, pomijam');
      return _default<T>(source);
    }

    await _acquire();
    try {
      await Future.delayed(minDelay);

      T? result;
      int attempts = 0;

      while (attempts < maxRetries) {
        attempts++;
        try {
          result = await request().timeout(const Duration(seconds: 15));
          _recordSuccess(source);
          break;
        } on TimeoutException {
          _recordFailure(source);
          if (attempts < maxRetries) {
            final backoff = Duration(seconds: 5 * attempts);
            debugPrint('SportsQueue: $source timeout #$attempts, retry za ${backoff.inSeconds}s');
            await Future.delayed(backoff);
          }
        } catch (e) {
          _recordFailure(source);
          if (attempts < maxRetries) {
            final backoff = Duration(seconds: 5 * attempts);
            debugPrint('SportsQueue: $source error #$attempts: $e, retry za ${backoff.inSeconds}s');
            await Future.delayed(backoff);
          }
        }
      }

      return result ?? _default<T>(source);
    } finally {
      _release();
    }
  }

  T _default<T>(String source) {
    debugPrint('SportsQueue: $source zwracam pustą listę (default)');
    // Pusta lista jest bezpiecznie kastowana do dowolnego List<T>
    return [] as T;
  }

  void resetAllCooldowns() {
    _sourceStates.clear();
  }

  Map<String, dynamic> getDiagnostics() {
    return {
      'running': _running,
      'waiting': _waiters.length,
      'sources': _sourceStates.map((k, v) => MapEntry(k, {
        'failures': v.failureCount,
        'cooldownUntil': v.cooldownUntil?.toIso8601String(),
        'isOnCooldown': v.isOnCooldown,
      })),
    };
  }
}
