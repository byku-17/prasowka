import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _secureStorage = FlutterSecureStorage();
  static const _saltKey = 'encryption_salt';
  static const _ivKey = 'encryption_iv';

  Future<Key> _getOrCreateKey(String userId, String password) async {
    final salt = await _getOrCreateSalt(userId);
    final keyBytes = _deriveKey(password, salt);
    return Key(keyBytes);
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

  Future<IV> _getOrCreateIV(String userId) async {
    final existing = await _secureStorage.read(key: '${_ivKey}_$userId');
    if (existing != null) {
      return IV(base64Url.decode(existing));
    }
    final iv = IV.fromSecureRandom(16);
    await _secureStorage.write(key: '${_ivKey}_$userId', value: base64Url.encode(iv.bytes));
    return iv;
  }

  Uint8List _generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
  }

  Uint8List _deriveKey(String password, Uint8List salt) {
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

  /// Szyfruje string AES-256-CBC
  Future<String> encryptText(String plainText, String userId, String password) async {
    final key = await _getOrCreateKey(userId, password);
    final iv = await _getOrCreateIV(userId);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.encrypt(plainText, iv: iv).base64;
  }

  /// Deszyfruje string AES-256-CBC
  Future<String> decryptText(String encryptedText, String userId, String password) async {
    final key = await _getOrCreateKey(userId, password);
    final iv = await _getOrCreateIV(userId);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt64(encryptedText, iv: iv);
  }

  /// Szyfruje mapę → JSON string → base64
  Future<String> encryptMap(Map<String, dynamic> data, String userId, String password) async {
    final json = jsonEncode(data);
    return encryptText(json, userId, password);
  }

  /// Deszyfruje base64 → JSON string → mapę
  Future<Map<String, dynamic>> decryptMap(String encrypted, String userId, String password) async {
    final json = await decryptText(encrypted, userId, password);
    return jsonDecode(json) as Map<String, dynamic>;
  }

  /// Szyfruje listę map
  Future<String> encryptList(List<Map<String, dynamic>> data, String userId, String password) async {
    final json = jsonEncode(data);
    return encryptText(json, userId, password);
  }

  /// Deszyfruje do listy map
  Future<List<Map<String, dynamic>>> decryptList(String encrypted, String userId, String password) async {
    final json = await decryptText(encrypted, userId, password);
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }
}
