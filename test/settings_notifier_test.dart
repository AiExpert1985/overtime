import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overtime/features/reporting/presentation/providers/settings_providers.dart';

import 'helpers/db_test_helper.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setupTestDatabase();
    container = ProviderContainer();
    // Wait for the notifier to finish loading from the DB.
    await container.read(settingsProvider.future);
  });

  tearDown(() => container.dispose());

  group('SettingsNotifier.removeShiftStartTime', () {
    test('removes a time when more than one entry exists', () async {
      final notifier = container.read(settingsProvider.notifier);
      await notifier.addShiftStartTime('14:00');

      await notifier.removeShiftStartTime('08:00');

      final times = container.read(settingsProvider).requireValue.shiftStartTimes;
      expect(times, isNot(contains('08:00')));
    });

    test('does not remove the last remaining entry', () async {
      final notifier = container.read(settingsProvider.notifier);

      // Remove until one is left, then attempt to remove it.
      await notifier.removeShiftStartTime('11:00');
      await notifier.removeShiftStartTime('08:00'); // must be ignored

      final times = container.read(settingsProvider).requireValue.shiftStartTimes;
      expect(times, hasLength(1));
      expect(times, contains('08:00'));
    });
  });
}
