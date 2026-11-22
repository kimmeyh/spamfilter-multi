// F354 (Sprint 85): the one-time copy that gives a Windows DEV build its own
// credential file. Uses temporary folders only; the real AppData folders are
// never touched.
//
// What this does NOT catch: that main.dart calls DevCredentialSeparation.run
// BEFORE the first credential read (checked by the order test below on the
// source text, and at Manual Validation by a DEV launch); that the copied
// file decrypts (DPAPI, same user, proven only by a real DEV launch showing
// its accounts); and a second process reading the DEV file during the copy.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:my_email_spam_filter/core/services/dev_credential_separation.dart';

void main() {
  late Directory root;
  late Directory prodDir;
  late Directory devDir;

  File prodFile() =>
      File(p.join(prodDir.path, DevCredentialSeparation.credentialFileName));
  File devFile() =>
      File(p.join(devDir.path, DevCredentialSeparation.credentialFileName));
  File marker() =>
      File(p.join(devDir.path, DevCredentialSeparation.markerFileName));
  String hash(File f) => sha256.convert(f.readAsBytesSync()).toString();

  setUp(() {
    root = Directory.systemTemp.createTempSync('f354_');
    prodDir = Directory(p.join(root.path, 'MyEmailSpamFilter'))..createSync();
    devDir = Directory(p.join(root.path, 'MyEmailSpamFilter_Dev'))
      ..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<DevCredentialResult> run({
    Directory? support,
    bool sharedStore = true,
    bool isDev = true,
  }) =>
      DevCredentialSeparation.run(
        supportDir: support ?? devDir,
        sharedStore: sharedStore,
        isDev: isDev,
        now: () => DateTime(2026, 11, 10, 9, 30, 5),
      );

  test('copies the production-named file into the DEV folder and leaves the '
      'production file byte-for-byte unchanged', () async {
    prodFile().writeAsBytesSync([1, 2, 3, 4, 5]);
    final before = hash(prodFile());

    expect(await run(), DevCredentialResult.copied);

    expect(devFile().readAsBytesSync(), [1, 2, 3, 4, 5]);
    expect(hash(prodFile()), before);
    expect(marker().existsSync(), isTrue);
  });

  test('keeps an earlier DEV credential file under a pre_f354 name, never '
      'deletes it', () async {
    prodFile().writeAsBytesSync([9, 9]);
    devFile().writeAsBytesSync([7]);

    expect(await run(), DevCredentialResult.copied);

    final kept = File('${devFile().path}.pre_f354_20261110_093005');
    expect(kept.readAsBytesSync(), [7]);
    expect(devFile().readAsBytesSync(), [9, 9]);
  });

  test('runs once: a second run is alreadyDone and does not copy again',
      () async {
    prodFile().writeAsBytesSync([1]);
    expect(await run(), DevCredentialResult.copied);
    devFile().writeAsBytesSync([2]); // DEV changed its own file since
    prodFile().writeAsBytesSync([3]);

    expect(await run(), DevCredentialResult.alreadyDone);
    expect(devFile().readAsBytesSync(), [2]);
  });

  test('no production-named file: nothingToCopy, marker written', () async {
    expect(await run(), DevCredentialResult.nothingToCopy);
    expect(devFile().existsSync(), isFalse);
    expect(marker().existsSync(), isTrue);
  });

  test('a failed copy writes NO marker (retried next launch) and leaves the '
      'production file unchanged', () async {
    prodFile().writeAsBytesSync([4, 4]);
    final before = hash(prodFile());
    // A directory where the DEV file must go makes the final rename fail.
    Directory(devFile().path).createSync();

    expect(await run(), DevCredentialResult.failed);
    expect(marker().existsSync(), isFalse);
    expect(hash(prodFile()), before);
    // Sprint 85 5.1.2 M3: the reason reaches main.dart, which writes it to a
    // log FILE (Logger is silent in a release build).
    expect(DevCredentialSeparation.lastError, isNotNull);

    Directory(devFile().path).deleteSync();
    expect(await run(), DevCredentialResult.copied);
    expect(DevCredentialSeparation.lastError, isNull,
        reason: 'a later success clears the old reason');
  });

  File lock() => File(p.join(devDir.path, DevCredentialSeparation.lockFileName));

  // Sprint 85 7.7.1 M4. What this does NOT catch: a marker write that fails on
  // the real disk for a reason other than the path being a folder.
  test('a marker that cannot be written after a good copy is its own result, '
      'not "failed"; the copy stays in place and the lock is released',
      () async {
    prodFile().writeAsBytesSync([5, 6]);
    Directory(marker().path).createSync(); // writing the marker file fails

    expect(await run(), DevCredentialResult.copiedMarkerNotWritten);
    expect(devFile().readAsBytesSync(), [5, 6]);
    expect(DevCredentialSeparation.lastError, contains('marker'));
    expect(lock().existsSync(), isFalse);
  });

  // Sprint 85 7.7.1 L1. What these do NOT catch: two real processes racing on
  // the real Windows file system (the exclusive create is the OS's guarantee).
  group('copy lock (UI and background process)', () {
    final savedWait = DevCredentialSeparation.lockWait;
    setUp(() => DevCredentialSeparation.lockWait =
        const Duration(milliseconds: 400));
    tearDown(() => DevCredentialSeparation.lockWait = savedWait);

    test('a lock held by another process: busy, nothing changed', () async {
      prodFile().writeAsBytesSync([1]);
      devFile().writeAsBytesSync([7]);
      lock().writeAsStringSync('held');

      expect(await run(), DevCredentialResult.busy);
      expect(devFile().readAsBytesSync(), [7]);
      expect(marker().existsSync(), isFalse);
      expect(DevCredentialSeparation.lastError, contains('lock'));
      expect(lock().existsSync(), isTrue,
          reason: 'another process owns it; this one must not remove it');
    });

    test('the other process finishes while this one waits: alreadyDone',
        () async {
      prodFile().writeAsBytesSync([1]);
      lock().writeAsStringSync('held');
      Future<void>.delayed(const Duration(milliseconds: 100),
          () => marker().writeAsStringSync('done'));

      expect(await run(), DevCredentialResult.alreadyDone);
      expect(devFile().existsSync(), isFalse);
    });

    test('a stale lock (process died mid-copy) is taken over', () async {
      prodFile().writeAsBytesSync([3]);
      lock().writeAsStringSync('old');
      lock().setLastModifiedSync(
          DateTime.now().subtract(const Duration(minutes: 5)));

      expect(await run(), DevCredentialResult.copied);
      expect(devFile().readAsBytesSync(), [3]);
      expect(lock().existsSync(), isFalse);
    });

    test('the lock is released after nothingToCopy and after a failure',
        () async {
      expect(await run(), DevCredentialResult.nothingToCopy);
      expect(lock().existsSync(), isFalse);

      marker().deleteSync();
      prodFile().writeAsBytesSync([4]);
      Directory(devFile().path).createSync();
      expect(await run(), DevCredentialResult.failed);
      expect(lock().existsSync(), isFalse);
    });
  });

  // Sprint 85 7.7.1 L1. What this does NOT catch: a name collision with a
  // file created between the existence check and the rename.
  test('an existing backup with the same stamp is never replaced', () async {
    prodFile().writeAsBytesSync([9]);
    devFile().writeAsBytesSync([7]);
    final first = File('${devFile().path}.pre_f354_20261110_093005')
      ..writeAsBytesSync([1]);

    expect(await run(), DevCredentialResult.copied);
    expect(first.readAsBytesSync(), [1]);
    expect(File('${first.path}_2').readAsBytesSync(), [7]);
  });

  test('main.dart writes a separation failure to the background log AND the '
      'diagnostic log (M3)', () {
    final src = File('lib/main.dart').readAsStringSync();
    expect(src, contains('DevCredentialSeparation.lastError'));
    expect(src, contains("await bgLog('F354: \$f354Problem')"));
    final diag = src.indexOf("context: 'F354'");
    expect(diag, greaterThan(0));
    expect(src.lastIndexOf('DiagnosticLogger.failure(', diag),
        greaterThan(src.indexOf("appEvent('app start (foreground)')")));
  });

  test('not applicable off Windows, in production, or from a pre-F354 exe '
      '(production-named support folder)', () async {
    prodFile().writeAsBytesSync([1]);
    expect(await run(sharedStore: false), DevCredentialResult.notApplicable);
    expect(await run(isDev: false), DevCredentialResult.notApplicable);
    expect(await run(support: prodDir), DevCredentialResult.notApplicable);
    expect(devFile().existsSync(), isFalse);
    expect(marker().existsSync(), isFalse);
  });

  test('main.dart runs the separation before the first credential read', () {
    final src = File('lib/main.dart').readAsStringSync();
    final sep = src.indexOf('DevCredentialSeparation.run(');
    final firstCred = src.indexOf('SecureCredentialsStore()');
    final bgBranch = src.indexOf('if (BackgroundModeService.isBackgroundMode)');
    expect(sep, greaterThan(0));
    expect(sep, lessThan(firstCred));
    expect(sep, lessThan(bgBranch),
        reason: 'the Task Scheduler path reads credentials too');
  });
}
