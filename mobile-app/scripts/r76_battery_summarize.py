"""SYNOPSIS: summarize one r76_battery_arm.sh output folder (Sprint 77 R76-1).
Usage: python r76_battery_summarize.py <arm output dir>
NOTE: the log timestamps are converted with a fixed EDT (UTC-4) offset and the app UID is
hard-coded to uid 10194 / u0a194 (the dev flavor on the 2026-10-07 AVD); edit both for another device."""
import glob
import re
import sys
from datetime import datetime, timezone, timedelta

d = sys.argv[1]
meta = open(d + "/meta.txt").read()
start = int(re.search(r"start epoch=(\d+)", meta).group(1))
idle = int(re.search(r"idle epoch=(\d+)", meta).group(1))
end = int(re.search(r"end epoch=(\d+)", meta).group(1))
posted = len(re.findall(r"^posted ", meta, re.M))
EDT = timedelta(hours=-4)


def ep(ts):
    dt = datetime.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone(EDT))
    return dt.timestamp()


starts = []
for f in glob.glob(d + "/diag/*.log"):
    for line in open(f, encoding="utf-8", errors="replace"):
        m = re.match(r"\[(\S+)\] \[SCAN\] \[worker/android\] start (.*)", line)
        if m:
            t = ep(m.group(1))
            tr = re.search(r"trigger=(\S+)", m.group(2))
            starts.append((t, tr.group(1) if tr else "?", m.group(2)))
starts.sort()
win = [s for s in starts if start <= s[0] <= end]
post_idle = [s for s in win if s[0] >= idle]
by = {}
for s in post_idle:
    by[s[1]] = by.get(s[1], 0) + 1
gaps = [post_idle[i + 1][0] - post_idle[i][0] for i in range(len(post_idle) - 1)]
print(f"window_s={end-start} idle_s={end-idle} notifications_posted={posted}")
print(f"worker starts after force-idle: {len(post_idle)} by trigger {by}; before idle in window: {len(win)-len(post_idle)}")
print("worker start offsets (s after force-idle):", [(round(s[0]-idle), s[1]) for s in post_idle])
print(f"longest gap between consecutive worker starts (s): {max(gaps) if gaps else 'n/a'}; "
      f"first start after idle: {round(post_idle[0][0]-idle) if post_idle else 'none'}s; "
      f"last start to window end: {round(end-post_idle[-1][0]) if post_idle else 'n/a'}s")


def grab(fn, pat, flags=0):
    try:
        t = open(d + "/" + fn, encoding="utf-8", errors="replace").read()
    except OSError:
        return []
    return re.findall(pat, t, flags)


uid_block = None
t = open(d + "/after_batterystats_full_pkg.txt", encoding="utf-8", errors="replace").read()
m = re.search(r"\n  u0a\d+:\n(.*?)\n  [A-Za-z]", t, re.S)
print("alarm package line (after):", grab("after_alarm.txt", r"u0a\d+:com\.myemailspamfilter\.dev[^\n]*\n[^\n]*\n[^\n]*"))
print("alarm package line (before):", grab("before_alarm.txt", r"u0a\d+:com\.myemailspamfilter\.dev[^\n]*"))
for pat in [r"Wakeup alarm [^\n]*", r"Total cpu time: [^\n]*", r"Job Completions[^\n]*", r"Job @[^\n]*",
            r"Total running: [^\n]*", r"Fg Service for: [^\n]*", r"TOTAL wake: [^\n]*",
            r"Mobile network:[^\n]*", r"Wi-Fi network:[^\n]*", r"Wifi Running[^\n]*"]:
    seg = t[t.find("\n  u0a194:"):] if "\n  u0a194:" in t else t
    print(pat[:20], "->", re.findall(pat, seg)[:6])
jobs = grab("after_jobscheduler.txt", r"^\s+(-[0-9ms]+)\s+START: #u0a194/(\d+)", re.M)
print("jobscheduler START entries for app in history (offset-from-dump, job id):", jobs)
b = grab("before_jobscheduler.txt", r"^\s+(-[0-9ms]+)\s+START: #u0a194/(\d+)", re.M)
print("  of which already present before window:", len(b))
for tag in ("before", "after"):
    ns = grab(tag + "_netstats.txt", r"uid=10194 set=(\w+) tag=0x0\n\s+NetworkStatsHistory[^\n]*\n((?:\s+st=[^\n]*\n)+)")
    print(tag, "netstats uid 10194:", ns)
