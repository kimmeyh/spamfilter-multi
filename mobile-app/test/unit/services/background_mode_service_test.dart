import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/background_mode_service.dart';

void main() {
  group('BackgroundModeService', () {
    setUp(() {
      // Reset mode before each test
      BackgroundModeService.resetForTesting();
    });

    group('initialize', () {
      test('detects background mode when flag is present', () {
        // Arrange
        final args = ['--background-scan'];

        // Act
        BackgroundModeService.initialize(args);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isTrue);
        expect(BackgroundModeService.isForegroundMode, isFalse);
      });

      test('detects foreground mode when flag is not present', () {
        // Arrange
        final args = <String>[];

        // Act
        BackgroundModeService.initialize(args);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isFalse);
        expect(BackgroundModeService.isForegroundMode, isTrue);
      });

      test('detects foreground mode with other arguments', () {
        // Arrange
        final args = ['--some-other-flag', '--debug'];

        // Act
        BackgroundModeService.initialize(args);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isFalse);
        expect(BackgroundModeService.isForegroundMode, isTrue);
      });

      test('detects background mode with multiple arguments', () {
        // Arrange
        final args = ['--debug', '--background-scan', '--verbose'];

        // Act
        BackgroundModeService.initialize(args);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isTrue);
      });
    });

    group('isBackgroundMode getter', () {
      test('returns true when initialized with background flag', () {
        // Arrange
        BackgroundModeService.initialize(['--background-scan']);

        // Act & Assert
        expect(BackgroundModeService.isBackgroundMode, isTrue);
      });

      test('returns false when initialized without background flag', () {
        // Arrange
        BackgroundModeService.initialize([]);

        // Act & Assert
        expect(BackgroundModeService.isBackgroundMode, isFalse);
      });
    });

    group('isForegroundMode getter', () {
      test('returns false when initialized with background flag', () {
        // Arrange
        BackgroundModeService.initialize(['--background-scan']);

        // Act & Assert
        expect(BackgroundModeService.isForegroundMode, isFalse);
      });

      test('returns true when initialized without background flag', () {
        // Arrange
        BackgroundModeService.initialize([]);

        // Act & Assert
        expect(BackgroundModeService.isForegroundMode, isTrue);
      });
    });

    group('resetForTesting', () {
      test('resets mode to foreground', () {
        // Arrange: Set to background mode
        BackgroundModeService.initialize(['--background-scan']);
        expect(BackgroundModeService.isBackgroundMode, isTrue);

        // Act
        BackgroundModeService.resetForTesting();

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isFalse);
        expect(BackgroundModeService.isForegroundMode, isTrue);
      });
    });

    group('setModeForTesting', () {
      test('sets background mode', () {
        // Act
        BackgroundModeService.setModeForTesting(isBackground: true);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isTrue);
        expect(BackgroundModeService.isForegroundMode, isFalse);
      });

      test('sets foreground mode', () {
        // Arrange: Start in background mode
        BackgroundModeService.setModeForTesting(isBackground: true);

        // Act
        BackgroundModeService.setModeForTesting(isBackground: false);

        // Assert
        expect(BackgroundModeService.isBackgroundMode, isFalse);
        expect(BackgroundModeService.isForegroundMode, isTrue);
      });
    });

    group('backgroundScanFlag constant', () {
      test('has correct value', () {
        // Assert
        expect(BackgroundModeService.backgroundScanFlag, equals('--background-scan'));
      });
    });
  });
}
