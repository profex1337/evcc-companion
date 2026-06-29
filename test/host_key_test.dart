import 'package:evcc_updater/src/host_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verifyHostKey', () {
    test('first use when nothing is stored yet', () {
      expect(verifyHostKey(stored: null, presented: 'SHA256:abc'),
          HostKeyVerdict.firstUse);
      expect(verifyHostKey(stored: '', presented: 'SHA256:abc'),
          HostKeyVerdict.firstUse);
    });

    test('match when the stored fingerprint equals the presented one', () {
      expect(verifyHostKey(stored: 'SHA256:abc', presented: 'SHA256:abc'),
          HostKeyVerdict.match);
    });

    test('changed when the fingerprints differ', () {
      expect(verifyHostKey(stored: 'SHA256:abc', presented: 'SHA256:xyz'),
          HostKeyVerdict.changed);
    });
  });

  group('hostKeyId', () {
    test('combines host and port into a stable storage key', () {
      expect(hostKeyId('192.168.178.64', 22), 'hostkey:192.168.178.64:22');
    });
  });
}
