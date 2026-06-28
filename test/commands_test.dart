import 'package:flutter_test/flutter_test.dart';
import 'package:evcc_updater/src/commands.dart';

void main() {
  group('buildUpdateSteps', () {
    test('evcc-only real run produces the validated SSH sequence in order', () {
      final steps = buildUpdateSteps(fullUpgrade: false, dryRun: false);

      expect(steps.map((s) => s.command).toList(), [
        r"dpkg-query -W -f='${Version}' evcc",
        'sudo -S apt-get update -qq',
        'sudo -S apt-get install --only-upgrade -y evcc',
        'systemctl is-active evcc',
        r"dpkg-query -W -f='${Version}' evcc",
      ]);
    });

    test('only the two apt-get steps require the sudo password on stdin', () {
      final steps = buildUpdateSteps(fullUpgrade: false, dryRun: false);

      expect(steps.map((s) => s.needsSudoPassword).toList(),
          [false, true, true, false, false]);
    });

    test('full upgrade swaps the upgrade step for apt-get full-upgrade -y', () {
      final steps = buildUpdateSteps(fullUpgrade: true, dryRun: false);

      expect(steps[2].command, 'sudo -S apt-get full-upgrade -y');
    });

    test('dry-run (evcc-only) adds --dry-run and drops -y', () {
      final steps = buildUpdateSteps(fullUpgrade: false, dryRun: true);

      expect(steps[2].command,
          'sudo -S apt-get install --only-upgrade --dry-run evcc');
    });

    test('dry-run (full upgrade) uses full-upgrade --dry-run', () {
      final steps = buildUpdateSteps(fullUpgrade: true, dryRun: true);

      expect(steps[2].command, 'sudo -S apt-get full-upgrade --dry-run');
    });

    test('every step carries a non-empty human label', () {
      final steps = buildUpdateSteps(fullUpgrade: false, dryRun: false);

      expect(steps.every((s) => s.label.trim().isNotEmpty), isTrue);
    });
  });
}
