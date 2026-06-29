import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'host_key.dart';

/// User-entered connection settings, persisted between launches.
class Settings {
  final String host;
  final String port;
  final String username;
  final String password;
  final bool fullUpgrade;

  const Settings({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.fullUpgrade,
  });

  static const empty = Settings(
    host: '',
    port: '22',
    username: 'pi',
    password: '',
    fullUpgrade: false,
  );
}

/// Persists [Settings] in the platform secure storage (Android Keystore-backed).
///
/// The password lives only here, encrypted at rest — never in plain prefs.
/// Tests subclass this and override [load]/[save] to avoid platform channels.
class SettingsStore {
  static const _kHost = 'host';
  static const _kPort = 'port';
  static const _kUser = 'user';
  static const _kPassword = 'password';
  static const _kFullUpgrade = 'fullUpgrade';

  final FlutterSecureStorage _storage;

  SettingsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<Settings> load() async {
    final all = await _storage.readAll();
    return Settings(
      host: all[_kHost] ?? Settings.empty.host,
      port: all[_kPort] ?? Settings.empty.port,
      username: all[_kUser] ?? Settings.empty.username,
      password: all[_kPassword] ?? Settings.empty.password,
      fullUpgrade: all[_kFullUpgrade] == 'true',
    );
  }

  Future<void> save(Settings s) async {
    await _storage.write(key: _kHost, value: s.host);
    await _storage.write(key: _kPort, value: s.port);
    await _storage.write(key: _kUser, value: s.username);
    await _storage.write(key: _kPassword, value: s.password);
    await _storage.write(key: _kFullUpgrade, value: s.fullUpgrade.toString());
  }
}

/// [HostKeyStore] backed by the platform secure storage.
class SecureHostKeyStore implements HostKeyStore {
  final FlutterSecureStorage _storage;

  SecureHostKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> get(String id) => _storage.read(key: id);

  @override
  Future<void> set(String id, String fingerprint) =>
      _storage.write(key: id, value: fingerprint);

  @override
  Future<void> remove(String id) => _storage.delete(key: id);
}
