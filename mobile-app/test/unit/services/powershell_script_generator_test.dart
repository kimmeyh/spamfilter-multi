/// SOURCE-TEXT VERIFIED: this proves the GENERATED PowerShell has the expected
/// shape. It cannot prove the script runs, because nothing here executes
/// PowerShell -- a syntactically plausible script with a wrong cmdlet name would
/// pass every assertion. What settles it is running the generated script on
/// Windows, which is what the scheduled-task path does in manual validation.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:my_email_spam_filter/core/services/powershell_script_generator.dart';
import 'package:my_email_spam_filter/core/services/scan_interval.dart';

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
          intervalMinutes: 15,
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

      test('F264 Q13: an interval over 15 minutes gets -RandomDelay, one at 15 '
          'or below gets none', () async {
        final long = await File(
                await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          intervalMinutes: 16,
          workingDirectory: workingDirectory,
        ))
            .readAsString();
        expect(long, contains('RandomDelay'),
            reason: 'Q13: jitter applies above 15 minutes');
        final short = await File(
                await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          intervalMinutes: 15,
          workingDirectory: workingDirectory,
        ))
            .readAsString();
        expect(short, isNot(contains('RandomDelay')),
            reason: 'Q13: none at 15 minutes or below');
      });

      test('F98: injects --account-id when accountId is provided', () async {
        final scriptPath =
            await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          intervalMinutes: 15,
          workingDirectory: workingDirectory,
          accountId: 'aol-a@b.com',
        );
        final content = await File(scriptPath).readAsString();
        expect(content, contains('--account-id=aol-a@b.com'));
      });

      test('generates script file for 30-minute frequency', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          intervalMinutes: 30,
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
          intervalMinutes: 60,
          workingDirectory: workingDirectory,
        );

        // Assert
        final content = await File(scriptPath).readAsString();
        expect(content, contains('Minutes 60'));
      });

      test('F264 AC-6: 5, 90, 1440 and 5940 minutes each get the ONE trigger '
          'shape, with the Q13 jitter rule and no -Daily', () async {
        // [interval, expects a RandomDelay of 10 minutes and an 11:55PM start]
        for (final c in [(5, false), (90, true), (1440, true), (5940, true)]) {
          final minutes = c.$1;
          for (final content in [
            await File(await PowerShellScriptGenerator.generateCreateTaskScript(
              taskName: taskName,
              executablePath: executablePath,
              intervalMinutes: minutes,
              workingDirectory: workingDirectory,
            )).readAsString(),
            await File(await PowerShellScriptGenerator.generateUpdateTaskScript(
              taskName: taskName,
              intervalMinutes: minutes,
            )).readAsString(),
          ]) {
            expect(content,
                contains('-RepetitionInterval (New-TimeSpan -Minutes $minutes)'),
                reason: '$minutes minutes must be the repetition interval');
            expect(content, isNot(contains('-Daily')),
                reason: 'a daily scan is just 1440 minutes (F264)');
            if (c.$2) {
              expect(content, contains('-At "11:55PM"'));
              expect(content, contains('-RandomDelay (New-TimeSpan -Minutes 10)'),
                  reason: 'start 5 minutes early plus 0-10 minutes of delay '
                      'is plus or minus 5 minutes around the nominal time');
            } else {
              expect(content, contains('-At "12:00AM"'));
              expect(content, isNot(contains('RandomDelay')));
            }
          }
        }
      });

      test('F264: the jitter constants are the shared ones (Windows trigger '
          'and Android alarm cannot drift)', () {
        // The Kotlin copies must equal the Dart constants the trigger uses.
        final kotlin = File(
                'android/app/src/main/kotlin/com/myemailspamfilter/DozeAlarmScheduler.kt')
            .readAsStringSync();
        expect(
            RegExp(r'THRESHOLD_MINUTES\s*=\s*(\d+)')
                .firstMatch(kotlin)
                ?.group(1),
            '$kJitterThresholdMinutes');
        expect(
            RegExp(r'JITTER_MINUTES\s*=\s*(\d+)').firstMatch(kotlin)?.group(1),
            '$kJitterMinutes');
        // The call site: the alarm's trigger time includes the jitter offset
        // (SOURCE-TEXT VERIFIED; a JVM test pins the function, not this call).
        expect(
            kotlin.contains(
                'AlarmJitter.offsetMs(intervalMinutes, java.util.Random())'),
            isTrue);
        // And the trigger text is derived from them, not literals.
        expect(PowerShellScriptGenerator.triggerForInterval(kJitterThresholdMinutes),
            isNot(contains('RandomDelay')));
        expect(
            PowerShellScriptGenerator.triggerForInterval(kJitterThresholdMinutes + 1),
            contains('-Minutes ${2 * kJitterMinutes}'));
      });

      test('script includes error handling', () async {
        // Act
        final scriptPath = await PowerShellScriptGenerator.generateCreateTaskScript(
          taskName: taskName,
          executablePath: executablePath,
          intervalMinutes: 15,
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
          intervalMinutes: 15,
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
          intervalMinutes: 30,
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
          intervalMinutes: 15,
          workingDirectory: workingDirectory,
        );

        // Get script directory path
        final tempDir = Directory.systemTemp;
        final scriptDir = Directory(path.join(tempDir.path, 'spam_filter_scripts'));

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
