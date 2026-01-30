import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:spam_filter_mobile/core/services/powershell_script_generator.dart';
import 'package:spam_filter_mobile/core/services/background_scan_manager.dart';

void main() {
  group('PowerShellScriptGenerator', () {
    const taskName = 'TestTask';
    const executablePath = 'C:\\\\Test\\\\App.exe';
    const workingDirectory = 'C:\\\\Test';

    tearDownAll(() async {
      // Cleanup any generated scripts
      await PowerShellScriptGenerator.cleanupScripts();
    });

    group('generateCreateTaskScript', () {
      test('generates script file for 15-minute frequency', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every15min,
          workingDirectory: workingDirectory,
        );

        // Assert
        expect(scriptPath, isNotEmpty);
        expect(scriptPath, endsWith('create_task.ps1'));
        expect(File(scriptPath).existsSync(), isTrue);

        // Verify script content
        final content = await File(scriptPath).readAsString();
        expect(content, contains(taskName));
        expect(content, contains(executablePath));
        expect(content, contains('--background-scan'));
        expect(content, contains('RepetitionInterval'));
        expect(content, contains('Minutes 15'));
      });

      test('generates script file for 30-minute frequency', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every30min,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('Minutes 30'));
      });

      test('generates script file for 1-hour frequency', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every1hour,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('Hours 1'));
      });

      test('generates script file for daily frequency', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.daily,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('-Daily'));
        expect(content, contains('09:00AM'));
      });

      test('script includes error handling', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every15min,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('try {'));
        expect(content, contains('catch {'));
        expect(content, contains('exit 0'));
        expect(content, contains('exit 1'));
      });

      test('script includes task settings', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every15min,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('AllowStartIfOnBatteries'));
        expect(content, contains('DontStopIfGoingOnBatteries'));
        expect(content, contains('RunOnlyIfNetworkAvailable'));
      });
    });

    group('generateUpdateTaskScript', () {
      test('generates update script', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateUpdateTaskScript(
          taskName: taskName,
          frequency: ScanFrequency.every30min,
        );

        // Assert
        expect(scriptPath, isNotEmpty);
        expect(scriptPath, endsWith('update_task.ps1'));
        expect(File(scriptPath).existsSync(), isTrue);

        // Verify script content
        final content = await File(scriptPath).readAsString();
        expect(content, contains(taskName));
        expect(content, contains('Get-ScheduledTask'));
        expect(content, contains('Set-ScheduledTask'));
        expect(content, contains('Minutes 30'));
      });
    });

    group('generateDeleteTaskScript', () {
      test('generates delete script', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateDeleteTaskScript(
          taskName: taskName,
        );

        // Assert
        expect(scriptPath, isNotEmpty);
        expect(scriptPath, endsWith('delete_task.ps1'));
        expect(File(scriptPath).existsSync(), isTrue);

        // Verify script content
        final content = await File(scriptPath).readAsString();
        expect(content, contains(taskName));
        expect(content, contains('Unregister-ScheduledTask'));
        expect(content, contains('-Confirm:\$false'));
      });

      test('handles task not found error', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateDeleteTaskScript(
          taskName: taskName,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('No MSFT_ScheduledTask'));
        expect(content, contains('does not exist'));
      });
    });

    group('generateGetStatusScript', () {
      test('generates status script', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateGetStatusScript(
          taskName: taskName,
        );

        // Assert
        expect(scriptPath, isNotEmpty);
        expect(scriptPath, endsWith('get_status.ps1'));
        expect(File(scriptPath).existsSync(), isTrue);

        // Verify script content
        final content = await File(scriptPath).readAsString();
        expect(content, contains(taskName));
        expect(content, contains('Get-ScheduledTask'));
        expect(content, contains('Get-ScheduledTaskInfo'));
        expect(content, contains('ConvertTo-Json'));
      });

      test('returns JSON status output', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateGetStatusScript(
          taskName: taskName,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('"exists"'));
        expect(content, contains('"state"'));
        expect(content, contains('"enabled"'));
        expect(content, contains('"lastRunTime"'));
        expect(content, contains('"nextRunTime"'));
      });
    });

    group('cleanupScripts', () {
      test('removes temp script directory', () async {
        // Arrange: Generate a script first
        await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          frequency: ScanFrequency.every15min,
          workingDirectory: workingDirectory,
        );

        // Get script directory path
        final tempDir = Directory.systemTemp;
        final scriptDir = Directory('${tempDir.path}\\spam_filter_scripts');

        // Verify directory exists
        expect(scriptDir.existsSync(), isTrue);

        // Act
        await PowerShellScriptGenerator.cleanupScripts();

        // Assert
        expect(scriptDir.existsSync(), isFalse);
      });
    });
  });
}
