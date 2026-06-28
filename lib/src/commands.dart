/// Pure construction of the SSH command sequence that updates evcc on a Pi.
///
/// No I/O happens here so the exact commands can be unit-tested without a real
/// SSH connection. The sequence mirrors the facts validated against the real
/// evcc-Pi on 2026-06-28.
library;

/// A single command in the update sequence.
class SshStep {
  /// Short human-readable label shown in the live log.
  final String label;

  /// The exact shell command to run on the Pi.
  final String command;

  /// Whether the sudo password must be fed to this command via stdin.
  ///
  /// The password is written to the command's stdin (for `sudo -S`) instead of
  /// being embedded in [command], so it can never end up in the command string
  /// or the visible log.
  final bool needsSudoPassword;

  const SshStep({
    required this.label,
    required this.command,
    required this.needsSudoPassword,
  });
}

/// Reads the installed version of the `evcc` package (no sudo needed).
const String versionQuery = r"dpkg-query -W -f='${Version}' evcc";

/// Queries whether the evcc service is running (no sudo needed).
const String serviceStatus = 'systemctl is-active evcc';

/// Builds the ordered update sequence.
///
/// - [fullUpgrade] `false` upgrades only evcc; `true` upgrades the whole system.
/// - [dryRun] `true` makes apt simulate the upgrade without changing anything.
List<SshStep> buildUpdateSteps({
  required bool fullUpgrade,
  required bool dryRun,
}) {
  return [
    const SshStep(
      label: 'Version vorher',
      command: versionQuery,
      needsSudoPassword: false,
    ),
    const SshStep(
      label: 'Paketliste aktualisieren',
      command: 'sudo -S apt-get update -qq',
      needsSudoPassword: true,
    ),
    SshStep(
      label: fullUpgrade ? 'System-Upgrade' : 'evcc aktualisieren',
      command: _upgradeCommand(fullUpgrade: fullUpgrade, dryRun: dryRun),
      needsSudoPassword: true,
    ),
    const SshStep(
      label: 'Dienststatus',
      command: serviceStatus,
      needsSudoPassword: false,
    ),
    const SshStep(
      label: 'Version nachher',
      command: versionQuery,
      needsSudoPassword: false,
    ),
  ];
}

String _upgradeCommand({required bool fullUpgrade, required bool dryRun}) {
  if (fullUpgrade) {
    return dryRun
        ? 'sudo -S apt-get full-upgrade --dry-run'
        : 'sudo -S apt-get full-upgrade -y';
  }
  return dryRun
      ? 'sudo -S apt-get install --only-upgrade --dry-run evcc'
      : 'sudo -S apt-get install --only-upgrade -y evcc';
}
