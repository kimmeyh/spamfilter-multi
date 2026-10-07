#!/usr/bin/env bash
# .SYNOPSIS
#   Run ONE timed battery-count arm on the Android emulator (Sprint 77 R76-1, Issue #464).
#
# .DESCRIPTION
#   Counts only (an emulator has no battery hardware, so it cannot measure energy):
#   wakeups, alarms, jobs, network bytes and CPU for the app UID, scans started
#   (diagnostic log `trigger=` lines), and the longest gap between scans.
#   Sequence: set standby bucket, unplug battery, reset batterystats, snapshot
#   dumpsys alarm/jobscheduler, screen off, wait 2 minutes, force Doze idle, run
#   the window (optionally posting a debug-package notification every N minutes
#   with `cmd notification post`, which posts as com.android.shell -- accepted
#   only by DEBUG builds, see MailNotificationPolicy.DEBUG_ONLY_PACKAGES), then
#   snapshot again and pull the diagnostic log. Leaves the device un-forced and
#   re-plugged.
#
# .PARAMETER 1  arm label, used for the output folder name
# .PARAMETER 2  window length in minutes (protocol: 60; shorter allowed, say so in the report)
# .PARAMETER 3  notification cadence in minutes (0 = none)
#
# .EXAMPLE
#   ANDROID_HOME=/c/Android/android-sdk bash mobile-app/scripts/r76_battery_arm.sh arm1 60 0
#
# Requires: adb from $ANDROID_HOME/platform-tools, a running emulator with the
# DEV flavor installed (package com.myemailspamfilter.dev), diagnostic log ON.
# Output: $OUT_ROOT/<arm>/ (default: ./r76_out).
set -u
ARM="${1:?arm label}"; MINUTES="${2:?minutes}"; CADENCE="${3:-0}"
PKG="${PKG:-com.myemailspamfilter.dev}"
ADB="$ANDROID_HOME/platform-tools/adb.exe"
export MSYS_NO_PATHCONV=1
OUT="${OUT_ROOT:-./r76_out}/$ARM"; mkdir -p "$OUT"
snap() { # $1 = before|after
  "$ADB" shell dumpsys alarm > "$OUT/$1_alarm.txt"
  "$ADB" shell dumpsys jobscheduler > "$OUT/$1_jobscheduler.txt"
  "$ADB" shell dumpsys batterystats "$PKG" > "$OUT/$1_batterystats_pkg.txt"
  "$ADB" shell dumpsys deviceidle get deep > "$OUT/$1_deviceidle.txt"
  # Per-UID bytes: netstats only flushes on a poll (default every 30 minutes), so force one.
  "$ADB" shell cmd netstats poll > /dev/null 2>&1
  "$ADB" shell dumpsys netstats detail > "$OUT/$1_netstats.txt"
}
START_EPOCH=$("$ADB" shell date +%s | tr -d '\r')
echo "$ARM start epoch=$START_EPOCH minutes=$MINUTES cadence=$CADENCE" | tee "$OUT/meta.txt"
"$ADB" shell am set-standby-bucket "$PKG" working_set
"$ADB" shell dumpsys battery unplug
"$ADB" shell dumpsys batterystats --reset > /dev/null
"$ADB" shell input keyevent KEYCODE_HOME
snap before
"$ADB" shell input keyevent KEYCODE_SLEEP
sleep 120
"$ADB" shell dumpsys deviceidle force-idle | tee -a "$OUT/meta.txt"
IDLE_EPOCH=$("$ADB" shell date +%s | tr -d '\r'); echo "idle epoch=$IDLE_EPOCH" >> "$OUT/meta.txt"
END=$(( IDLE_EPOCH + MINUTES * 60 )); N=0
while [ "$("$ADB" shell date +%s | tr -d '\r')" -lt "$END" ]; do
  if [ "$CADENCE" -gt 0 ]; then
    N=$((N+1))
    "$ADB" shell cmd notification post -t "r761 test $N" "r761tag$N" "r761 body $N" > /dev/null 2>&1
    echo "posted $N at $("$ADB" shell date +%s | tr -d '\r')" >> "$OUT/meta.txt"
    sleep $((CADENCE * 60))
  else
    sleep 60
  fi
done
snap after
"$ADB" shell dumpsys deviceidle unforce
"$ADB" shell dumpsys battery reset
"$ADB" shell dumpsys batterystats "$PKG" > "$OUT/after_batterystats_full_pkg.txt"
"$ADB" shell dumpsys batterystats --checkin "$PKG" > "$OUT/after_batterystats_checkin.txt" 2>&1
rm -rf "$OUT/diag"; "$ADB" pull /sdcard/Documents/diagnostics_Dev "$OUT/diag" > /dev/null 2>&1
echo "end epoch=$("$ADB" shell date +%s | tr -d '\r') notifications_posted=$N" >> "$OUT/meta.txt"
"$ADB" shell input keyevent KEYCODE_WAKEUP
