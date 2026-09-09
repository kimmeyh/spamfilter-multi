# Sprint 67 -- running notes for the retrospective

Captured during the sprint so they are not reconstructed from memory at Phase 7.

## Q&A format violation (Harold, 2026-09-09)

Asked the emulator uninstall-vs-release-build question as prose with two bolded
paragraphs and a lean, then "Which do you want?". Harold: *"noting this is not
how I have requested you ask questions."*

The standing rule (`feedback_qa_style_plain_numbered`, corrected 3x on
2026-08-10) is a PLAIN NUMBERED LIST the user answers by typing a digit:

    1. Uninstall the release package and install the debug build
    2. Build a release APK instead, which upgrades in place

Also relevant: `feedback_yes_no_questions` -- a decision question must be
yes/no or select 1/2/3/all, and "yes" must never imply two answers.

This is a recurring correction, not a first offence, which is what makes it
retrospective material rather than a one-line fix.

## Emulator "broken" -- wrong conclusion from one failed launch

Reported `pixel34_updated` as an unfixable SDK toolchain fault after a single
hardcoded-path launch failed. Harold refused it: the emulator is the ONLY
pre-Store Android test path, so "it must work".

Cause was mine. Two Android SDK installs exist:
  - `C:\Android\android-sdk\emulator`        -> 36.2.12.0 (current, ANDROID_HOME)
  - `%LOCALAPPDATA%\Android\Sdk\emulator`    -> 29.3.4.0  (2019 leftover)

I hardcoded the second. Emulator 29 predates the kernel format Android 34
images use, which produced a misleading "Can't find 'Linux version' string"
error that reads like a corrupt image. Nothing was broken; the fix was to use
`$env:ANDROID_HOME`, which was already correct.

Recorded in `docs/TROUBLESHOOTING.md`. The generalisable lesson: on a machine
with two toolchain installs, a hardcoded path silently selects the wrong one,
and the resulting error describes a symptom rather than a cause.

Related to CLAUDE.md's existing rule about hand-writing commands for repo
scripts (Sprint 66 IMP-1) -- same family: bypassing the configured entry point.

## Wording

"Interrupted" -> "Not finished" in Scan History (Harold's preference, after
first suggesting "Did not finish" and then revising).
