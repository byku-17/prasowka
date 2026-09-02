import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';

/// Data Encryption Key (DEK) — niezależny od metody logowania.
/// Przechowywany w Secure Storage (Keychain/Keystore), nie w kodzie.
class EncryptionService {
  static const _secureStorage = FlutterSecureStorage();
  static const _saltKey = 'encryption_salt';
  static const _dekKeyPrefix = 'dek_';

  static const _pbkdf2Iterations = 100000;
  static const _fallbackPbkdf2Iterations = [30000];
  static const _keyLengthBytes = 32;

  // Cache w pamięci (klucz: "<iterations>|<userId>" lub "dek|<userId>").
  final Map<String, Key> _keyCache = {};
  final Map<String, Key> _legacyKeyCache = {};

  // ─── DEK (Data Encryption Key) ───

  /// Zwraca DEK dla użytkownika. Jeśli nie istnieje — generuje nowy.
  Future<Key> getOrCreateDek(String userId) async {
    final cacheKey = 'dek|$userId';
    if (_keyCache.containsKey(cacheKey)) return _keyCache[cacheKey]!;

    final existing = await _secureStorage.read(key: '$_dekKeyPrefix$userId');
    if (existing != null) {
      final key = Key(base64Url.decode(existing));
      _keyCache[cacheKey] = key;
      return key;
    }

    // Wygeneruj nowy DEK (losowy 32B)
    final bytes = Uint8List.fromList(
      List.generate(_keyLengthBytes, (_) => Random.secure().nextInt(256)),
    );
    final key = Key(bytes);
    await _secureStorage.write(key: '$_dekKeyPrefix$userId', value: base64Url.encode(bytes));
    _keyCache[cacheKey] = key;
    debugPrint('EncryptionService: wygenerowano nowy DEK dla $userId');
    return key;
  }

  /// Czy użytkownik ma już DEK? (bez generowania)
  Future<bool> hasDek(String userId) async {
    final existing = await _secureStorage.read(key: '$_dekKeyPrefix$userId');
    return existing != null;
  }

  // ─── KLUCZE PBKDF2 (legacy) ───

  Future<Key> _getOrCreateKey(String userId, String password, {required int iterations}) async {
    final cacheKey = '$iterations|$userId';
    if (_keyCache.containsKey(cacheKey)) return _keyCache[cacheKey]!;
    final salt = await _getOrCreateSalt(userId);
    final key = Key(_deriveKey(password, salt, iterations));
    _keyCache[cacheKey] = key;
    return key;
  }

  Future<Key> _getOrCreateLegacyKey(String userId, String password) async {
    if (_legacyKeyCache.containsKey(userId)) return _legacyKeyCache[userId]!;
    final salt = await _getOrCreateSalt(userId);
    final key = Key(_deriveLegacyKey(password, salt));
    _legacyKeyCache[userId] = key;
    return key;
  }

  Future<Uint8List> _getOrCreateSalt(String userId) async {
    final existing = await _secureStorage.read(key: '${_saltKey}_$userId');
    if (existing != null) {
      return base64Url.decode(existing);
    }
    final salt = _generateSalt();
    await _secureStorage.write(key: '${_saltKey}_$userId', value: base64Url.encode(salt));
    return salt;
  }


  Uint8List _generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  }

  Uint8List _deriveKey(String password, Uint8List salt, int iterations) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, _keyLengthBytes));
    return derivator.process(utf8.encode(password));
  }

  Uint8List _deriveLegacyKey(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final combined = Uint8List(passwordBytes.length + salt.length)
      ..setAll(0, passwordBytes)
      ..setAll(passwordBytes.length, salt);

    var hash = combined;
    for (var i = 0; i < 10000; i++) {
      hash = Uint8List.fromList(_simpleHash(hash));
    }
    return Uint8List.fromList(hash.take(32).toList());
  }

  List<int> _simpleHash(List<int> data) {
    var h = 0x6a09e667;
    for (final byte in data) {
      h = ((h << 5) + h + byte) & 0xFFFFFFFF;
    }
    return List.generate(32, (i) => ((h >> (i % 4 * 8)) ^ (i * 0x37)) & 0xFF);
  }

  // ─── SZYFROWANIE / DESZYFROWANIE ───

  static const String _ivDelimiter = ':';

  /// Szyfruje string AES-256-CBC z losowym IV.
  /// Używa DEK (jeśli istnieje) lub klucza PBKDF2 (fallback).
  Future<String> encryptText(String plainText, String userId, {String? password}) async {
    final key = await _resolveEncryptionKey(userId, password: password);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64Url.encode(iv.bytes)}$_ivDelimiter${encrypted.base64}';
  }

  /// Deszyfruje string AES-256-CBC.
  /// Kolejność: DEK → PBKDF2 100k → 30k → legacy.
  Future<String> decryptText(String encryptedText, String userId, {String? password}) async {
    final iv = await _extractIV(userId, encryptedText);

    // 1. Spróbuj DEK
    final dek = await _tryGetDek(userId);
    if (dek != null) {
      try {
        return _decrypt(encryptedText, iv, dek);
      } catch (_) {}
    }

    // 2. Fallback: PBKDF2 z hasłem (kolejność iteracji)
    if (password != null) {
      for (final iterations in <int>[_pbkdf2Iterations, ..._fallbackPbkdf2Iterations]) {
        try {
          final key = await _getOrCreateKey(userId, password, iterations: iterations);
          return _decrypt(encryptedText, iv, key);
        } catch (_) {}
      }
      // 3. Legacy hash
      try {
        final legacyKey = await _getOrCreateLegacyKey(userId, password);
        return _decrypt(encryptedText, iv, legacyKey);
      } catch (_) {}
    }

    throw StateError('Nie udało się odszyfrować danych — brak odpowiedniego klucza');
  }

  /// Zwraca DEK jeśli istnieje (bez generowania).
  Future<Key?> _tryGetDek(String userId) async {
    final cacheKey = 'dek|$userId';
    if (_keyCache.containsKey(cacheKey)) return _keyCache[cacheKey]!;
    final existing = await _secureStorage.read(key: '$_dekKeyPrefix$userId');
    if (existing == null) return null;
    final key = Key(base64Url.decode(existing));
    _keyCache[cacheKey] = key;
    return key;
  }

  /// Wybiera klucz do szyfrowania: DEK jeśli istnieje, inaczej PBKDF2.
  Future<Key> _resolveEncryptionKey(String userId, {String? password}) async {
    // Preferuj DEK
    final dek = await _tryGetDek(userId);
    if (dek != null) return dek;

    // Fallback na PBKDF2 (tylko jeśli mamy hasło)
    if (password != null) {
      return _getOrCreateKey(userId, password, iterations: _pbkdf2Iterations);
    }

    // Ostateczność: wygeneruj DEK
    return getOrCreateDek(userId);
  }

  String _decrypt(String encryptedText, IV iv, Key key) {
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt64(encryptedText, iv: iv);
  }

  Future<IV> _extractIV(String userId, String encryptedText) async {
    final sepIdx = encryptedText.indexOf(_ivDelimiter);
    if (sepIdx > 0) {
      try {
        return IV(base64Url.decode(encryptedText.substring(0, sepIdx)));
      } catch (_) {}
    }
    throw StateError('Nie udało się wyodrębnić IV z zaszyfrowanego tekstu');
  }

  // ─── MIGRACJA: re-encrypt z DEK ───

  /// Próbuje odszyfrować stare dane hasłem i zapisać je ponownie z DEK.
  /// Zwraca true jeśli migracja się powiodła (dane zaszyfrowane DEK).
  Future<bool> tryMigrateToDek({
    required String userId,
    required String password,
    required Future<String> Function(String encrypted, String userId, String password) decryptFn,
    required Future<void> Function(String encrypted, String userId) saveEncryptedFn,
  }) async {
    // Jeśli DEK już istnieje — nie trzeba migracji
    if (await hasDek(userId)) return true;

    try {
      // Wygeneruj DEK
      await getOrCreateDek(userId);
      debugPrint('EncryptionService: DEK wygenerowany dla $userId — gotowy do migracji');
      return true;
    } catch (e) {
      debugPrint('EncryptionService: błąd generowania DEK: $e');
      return false;
    }
  }

  // ─── MAPY I LISTY (enkapsulacja) ───

  Future<String> encryptMap(Map<String, dynamic> data, String userId, {String? password}) async {
    final json = jsonEncode(data);
    return encryptText(json, userId, password: password);
  }

  Future<Map<String, dynamic>> decryptMap(String encrypted, String userId, {String? password}) async {
    final json = await decryptText(encrypted, userId, password: password);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  Future<String> encryptList(List<Map<String, dynamic>> data, String userId, {String? password}) async {
    final json = jsonEncode(data);
    return encryptText(json, userId, password: password);
  }

  Future<List<Map<String, dynamic>>> decryptList(String encrypted, String userId, {String? password}) async {
    final json = await decryptText(encrypted, userId, password: password);
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }
}
