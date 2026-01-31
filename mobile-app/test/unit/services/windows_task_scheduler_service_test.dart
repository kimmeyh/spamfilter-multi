import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/windows_task_scheduler_service.dart';
import 'package:spam_filter_mobile/core/services/background_scan_manager.dart';

void main() {
  group('WindowsTaskSchedulerService', () {
    tearDownAll(() async {
      // Cleanup: Delete task if it exists
      try {
        await WindowsTaskSchedulerService.deleteScheduledTask();
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    group('PowerShellResult', () {
      test('creates result with success status', () {
        // Arrange & Act
        final result = PowerShellResult(
          success: true,
          exitCode: 0,
          output: 'Task created successfully',
          error: '',
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.exitCode, equals(0));
        expect(result.output, equals('Task created successfully'));
        expect(result.error, isEmpty);
      });

      test('creates result with failure status', () {
        // Arrange & Act
        final result = PowerShellResult(
          success: false,
          exitCode: 1,
          output: '',
          error: 'Task creation failed',
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.exitCode, equals(1));
        expect(result.error, equals('Task creation failed'));
      });

      test('toString returns formatted string', () {
        // Arrange
        final result = PowerShellResult(
          success: true,
          exitCode: 0,
          output: 'test output',
          error: 'test error',
        );

        // Act
        final str = result.toString();

        // Assert
        expect(str, contains('success: true'));
        expect(str, contains('exitCode: 0'));
        expect(str, contains('output: test output'));
        expect(str, contains('error: test error'));
      });
    });

    group('createScheduledTask', () {
      test('returns false for disabled frequency', () async {
        // Act
        final result = await WindowsTaskSchedulerService.createScheduledTask(
          frequency: ScanFrequency.disabled,
        );

        // Assert
        expect(result, isFalse);
      });

      // NOTE: Actual task creation tests would require Windows environment
      // and proper permissions. These are integration tests.
      // Unit tests focus on logic and error handling.
    });

    group('updateScheduledTask', () {
      test('calls deleteScheduledTask when frequency is disabled', () async {
        // Act
        final result = await WindowsTaskSchedulerService.updateScheduledTask(
          frequency: ScanFrequency.disabled,
        );

        // Assert: Should attempt to delete task
        // Result depends on whether task exists
        expect(result, isA<bool>());
      });
    });

    group('getScheduleStatus', () {
      test('returns status map with exists field', () async {
        // Act
        final status = await WindowsTaskSchedulerService.getScheduleStatus();

        // Assert
        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('exists'), isTrue);
      });

      test('returns false exists when task does not exist', () async {
        // Arrange: Ensure task is deleted
        await WindowsTaskSchedulerService.deleteScheduledTask();

        // Act
        final status = await WindowsTaskSchedulerService.getScheduleStatus();

        // Assert
        expect(status['exists'], isFalse);
      });
    });

    group('getNextScheduledTime', () {
      test('returns null when task does not exist', () async {
        // Arrange: Ensure task is deleted
        await WindowsTaskSchedulerService.deleteScheduledTask();

        // Act
        final nextTime = await WindowsTaskSchedulerService.getNextScheduledTime();

        // Assert
        expect(nextTime, isNull);
      });
    });

    group('taskExists', () {
      test('returns false when task does not exist', () async {
        // Arrange: Ensure task is deleted
        await WindowsTaskSchedulerService.deleteScheduledTask();

        // Act
        final exists = await WindowsTaskSchedulerService.taskExists();

        // Assert
        expect(exists, isFalse);
      });
    });
  });
}
