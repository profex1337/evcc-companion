import 'dart:convert';
import 'dart:typed_data';

import 'package:evcc_updater/src/dartssh2_runner.dart';
import 'package:evcc_updater/src/host_key.dart';
import 'package:evcc_updater/src/ssh_runner.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHostKeyStore implements HostKeyStore {
  final Map<String, String> data;
  FakeHostKeyStore([Map<String, String>? initial]) : data = {...?initial};
  @override
  Future<String?> get(String id) async => data[id];
  @override
  Future<void> set(String id, String fingerprint) async =>
      data[id] = fingerprint;
  @override
  Future<void> remove(String id) async => data.remove(id);
}

const _config =
    SshConfig(host: '192.168.178.64', port: 22, username: 'pi', password: 'pw');

Uint8List _fp(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('Dartssh2Runner.checkAndRecordHostKey (TOFU glue)', () {
    final id = hostKeyId(_config.host, _config.port);

    test('first use: records the key and accepts', () async {
      final store = FakeHostKeyStore();
      final runner = Dartssh2Runner(_config, hostKeyStore: store);

      final accepted = await runner.checkAndRecordHostKey(_fp('SHA256:aaa'));

      expect(accepted, isTrue);
      expect(store.data[id], 'SHA256:aaa'); // trusted on first use
    });

    test('match: accepts without rewriting the store', () async {
      final store = FakeHostKeyStore({id: 'SHA256:aaa'});
      final runner = Dartssh2Runner(_config, hostKeyStore: store);

      final accepted = await runner.checkAndRecordHostKey(_fp('SHA256:aaa'));

      expect(accepted, isTrue);
      expect(store.data[id], 'SHA256:aaa');
      expect(runner.changedFingerprint, isNull);
    });

    test('changed: rejects, leaves the stored key, records the new fingerprint',
        () async {
      final store = FakeHostKeyStore({id: 'SHA256:old'});
      final runner = Dartssh2Runner(_config, hostKeyStore: store);

      final accepted = await runner.checkAndRecordHostKey(_fp('SHA256:new'));

      expect(accepted, isFalse); // aborts the handshake → no password sent
      expect(store.data[id], 'SHA256:old'); // NOT overwritten
      expect(runner.changedFingerprint, 'SHA256:new');
    });
  });
}
