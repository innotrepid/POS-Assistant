import 'package:flutter_test/flutter_test.dart';
import 'package:mercate/core/models/mercate_license.dart';

void main() {
  group('formatLicenseCountdown', () {
    test('formats days, hours and minutes without changing the instant', () {
      expect(
        formatLicenseCountdown(
          const Duration(days: 2, hours: 3, minutes: 4),
        ),
        '2d 3h 4m',
      );
    });

    test('rounds a partial minute up so an active licence never shows zero', () {
      expect(
        formatLicenseCountdown(const Duration(seconds: 1)),
        '1m',
      );
    });

    test('omits zero day and hour units', () {
      expect(
        formatLicenseCountdown(const Duration(hours: 2, minutes: 7)),
        '2h 7m',
      );
    });

    test('reports elapsed expiry as expired', () {
      expect(formatLicenseCountdown(Duration.zero), 'Expired');
      expect(
        formatLicenseCountdown(const Duration(seconds: -1)),
        'Expired',
      );
    });
  });
}
