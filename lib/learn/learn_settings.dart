import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String kDefaultLearnModel = 'deepseek/deepseek-v4-flash-0731';

/// OpenRouter ids are `vendor/model`. litellm-style ids carry an extra
/// `openrouter/` prefix the API itself rejects, so it is stripped.
String normalizeModelId(String? raw) {
  var id = (raw ?? '').trim();
  if (id.startsWith('openrouter/')) id = id.substring('openrouter/'.length);
  return id.isEmpty ? kDefaultLearnModel : id;
}

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android Keystore-backed. Deliberately not the deck database: that
/// file is what Drive backups upload, and a key must never travel.
class KeystoreSecretStore implements SecretStore {
  const KeystoreSecretStore();

  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions());

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : _values = {...?initial};
  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// The OpenRouter key and model, and whether the Learn tab exists at
/// all: it is shown only while a key is stored. Both stay on this
/// device; neither travels with a Drive backup.
class LearnSettings {
  LearnSettings(this._store);

  static LearnSettings instance = LearnSettings(const KeystoreSecretStore());

  static const _apiKeyName = 'openrouter_api_key';
  static const _modelName = 'openrouter_model';

  final SecretStore _store;
  final ValueNotifier<bool> available = ValueNotifier(false);
  String? _key;
  String? _model;
  bool _loaded = false;

  Future<void> load() async {
    try {
      _key = await _store.read(_apiKeyName);
      _model = await _store.read(_modelName);
    } catch (_) {
      // Keystore unavailable (tests, a restored device whose key can no
      // longer be unwrapped): behave as if nothing was ever saved.
      _key = null;
      _model = null;
    }
    _loaded = true;
    available.value = (_key ?? '').isNotEmpty;
  }

  Future<String?> apiKey() async {
    if (!_loaded) await load();
    return _key;
  }

  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return clearApiKey();
    await _store.write(_apiKeyName, trimmed);
    _key = trimmed;
    _loaded = true;
    available.value = true;
  }

  /// The model to use: the one chosen in Settings, else the default.
  Future<String> model() async {
    if (!_loaded) await load();
    return normalizeModelId(_model);
  }

  /// Choosing the default (or nothing) clears the setting, so a later
  /// release that changes the default moves this device with it.
  Future<void> setModel(String? raw) async {
    final id = normalizeModelId(raw);
    if (id == kDefaultLearnModel) {
      await _store.delete(_modelName);
      _model = null;
    } else {
      await _store.write(_modelName, id);
      _model = id;
    }
  }

  Future<void> clearApiKey() async {
    await _store.delete(_apiKeyName);
    _key = null;
    _loaded = true;
    available.value = false;
  }

  static String mask(String key) => key.length <= 12
      ? '••••'
      : '${key.substring(0, 6)}…${key.substring(key.length - 4)}';
}
