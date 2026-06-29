import 'package:evcc_updater/src/profiles.dart';
import 'package:evcc_updater/src/settings_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [FlutterSecureStorage] for tests — intercepts every call via
/// [noSuchMethod] so we don't have to match the (option-heavy) signatures.
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> data;
  FakeSecureStorage([Map<String, String>? initial]) : data = {...?initial};

  @override
  dynamic noSuchMethod(Invocation i) {
    switch (i.memberName) {
      case #read:
        return Future.value(data[i.namedArguments[#key]]);
      case #write:
        final k = i.namedArguments[#key] as String;
        final v = i.namedArguments[#value] as String?;
        if (v == null) {
          data.remove(k);
        } else {
          data[k] = v;
        }
        return Future.value();
      case #delete:
        data.remove(i.namedArguments[#key]);
        return Future.value();
      case #deleteAll:
        data.clear();
        return Future.value();
      case #readAll:
        return Future.value(Map<String, String>.from(data));
      case #containsKey:
        return Future.value(data.containsKey(i.namedArguments[#key]));
      default:
        return Future.value();
    }
  }
}

void main() {
  group('SettingsStore', () {
    test('clear() deletes exactly the keys save() wrote', () async {
      final fake = FakeSecureStorage();
      final store = SettingsStore(fake);

      await store.save(const Settings(
        host: '192.168.178.64',
        port: '22',
        username: 'pi',
        password: 'secret',
        fullUpgrade: true,
      ));
      expect(fake.data['host'], '192.168.178.64');
      expect(fake.data['password'], 'secret');
      expect(fake.data.isNotEmpty, isTrue);

      await store.clear();
      // Every flat credential key must be gone — no stale copy left behind.
      expect(fake.data, isEmpty);
    });
  });

  group('AppConfigStore.load migration', () {
    test('migrates legacy flat keys, persists app_config, purges the legacy keys',
        () async {
      final fake = FakeSecureStorage({
        'host': '192.168.178.64',
        'user': 'pi',
        'password': 'secret',
        'fullUpgrade': 'true',
        'themeMode': 'dark',
      });
      final config = await AppConfigStore(fake).load();

      // Migrated into a single "Standard" profile.
      expect(config.active.host, '192.168.178.64');
      expect(config.active.password, 'secret');
      expect(config.active.fullUpgrade, isTrue);
      expect(config.themeMode, 'dark');
      // The new config is now persisted...
      expect(fake.data['app_config_v1'], isNotNull);
      // ...and the legacy flat credential keys are purged.
      expect(fake.data['host'], isNull);
      expect(fake.data['password'], isNull);
    });

    test('with app_config_v1 present, the legacy keys are left untouched',
        () async {
      final existing = encodeAppConfig(const AppConfig(
        profiles: [Profile(name: 'Pi', host: '10.0.0.5', password: 'pw')],
        activeIndex: 0,
      ));
      final fake = FakeSecureStorage({
        'app_config_v1': existing,
        'host': 'legacy-should-stay', // a stray legacy key
      });
      final config = await AppConfigStore(fake).load();

      expect(config.active.host, '10.0.0.5');
      // No migration ran → the stray legacy key is not cleared.
      expect(fake.data['host'], 'legacy-should-stay');
    });
  });
}
