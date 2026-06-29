/// Trust-On-First-Use (TOFU) host-key verification — pure logic + storage seam.
///
/// dartssh2 hands us the OpenSSH-style `SHA256:<base64>` fingerprint directly,
/// so there's nothing to hash here: we just remember it on first use and compare
/// it afterwards.
library;

/// Outcome of comparing a presented host-key fingerprint to the stored one.
enum HostKeyVerdict {
  /// Nothing stored yet for this host → remember it and proceed.
  firstUse,

  /// Matches what we trusted before → proceed.
  match,

  /// Differs from what we trusted → block (possible MITM, or re-flashed Pi).
  changed,
}

/// Compares a [presented] fingerprint against the [stored] one (if any).
HostKeyVerdict verifyHostKey({
  required String? stored,
  required String presented,
}) {
  if (stored == null || stored.isEmpty) return HostKeyVerdict.firstUse;
  return stored == presented ? HostKeyVerdict.match : HostKeyVerdict.changed;
}

/// Stable storage key for a host's trusted fingerprint.
String hostKeyId(String host, int port) => 'hostkey:$host:$port';

/// Persists trusted host-key fingerprints. Real impl uses secure storage; tests
/// fake it.
abstract class HostKeyStore {
  Future<String?> get(String id);
  Future<void> set(String id, String fingerprint);
  Future<void> remove(String id);
}
