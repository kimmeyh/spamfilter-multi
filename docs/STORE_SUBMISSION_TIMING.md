# Store Submission Timing

Turnaround history for Microsoft Store submissions: how long each one took from
**submit** to **certified/live**. Purpose is planning -- deciding whether a release
started tonight can realistically be live tomorrow.

**Timestamps are derived from this repo's git history**, specifically the commits
that recorded each submission and each certification in `.claude/sprint_status.json`
and `docs/STORE_VERSION_STATUS.md`. That makes them accurate to when the event was
*recorded*, which for submissions is within minutes (the commit is made right after
the upload) but for certifications can lag by hours -- a submission that certifies
overnight is typically recorded the next morning. **Treat certification times as an
upper bound, never as a precise measurement.** Partner Center is the only exact
source, and it is not machine-readable from this repo (no API credentials
configured; the dashboard requires an interactive authenticated session).

## History

| Submission | Version | Submitted (recorded) | Certified/live (recorded) | Elapsed (upper bound) |
|---|---|---|---|---|
| 18 | 0.11.0.0 | 2026-08-22 ~10:10 (Harold's upload, a few minutes before polling began 10:13) | 2026-08-22 between 10:33 and 10:41 (Playwright, 5-min poll; "Congrats! Your product is now updated" at the 10:41 check; certification had PASSED by the 10:28 check, publishing took the remainder) | **~25-30 minutes** (measured at 5-min cadence -- confirms the ~26-min Submission 17 figure; pre-processing ~5-10 min, certification ~5-10 min, publishing ~10 min) |
| 19 | 0.12.0.0 | 2026-08-24 ~8:5x am ET (Harold's upload; screenshot at Pre-processing) | 2026-08-24 by ~9:12 am ET (Playwright, direct observation: "Congrats! Your product is now updated"; was at Certification step 3/4 at the ~8:51 check) | **~20-25 minutes** (third consecutive measurement in the 20-30 min band) |
| 17 | 0.10.0.0 | 2026-08-16 21:51 | 2026-08-16 22:17 (Playwright, 10-min poll) | **~26 minutes** (measured) |
| 16 | 0.9.0.0 | 2026-08-15 22:56 | 2026-08-16 (Harold, Partner Center screenshot) | < 24h |
| 15 | 0.8.0.0 | 2026-08-15 18:45 | 2026-08-15 19:36 | **~51 minutes** |
| 14 | 0.7.0.0 | 2026-08-14 11:28 (uploaded as draft) | 2026-08-15 11:20 | ~24h (draft-first, so not a clean measure) |
| 13 | 0.6.2.0 | 2026-08-13 08:59 | 2026-08-13 16:00 | **~7 hours** |
| 12 | 0.6.1.0 | 2026-08-12 08:36 | (not separately recorded) | -- |
| 11 | 0.6.0.0 | 2026-08-09 23:37 | 2026-08-10 09:59 | ~10h (overnight -- includes sleep time) |
| 10 | 0.5.9.0 | 2026-08-03 09:07 | 2026-08-03 (same day, per the F-STORE-53 record) | < 1 day |

## What the numbers actually say

- **MEASURED FLOOR: ~26 minutes (Submission 17).** The first submission polled at a
  fixed 10-minute cadence went submit-to-live in about 26 minutes: submitted 21:51,
  pre-processing 21:57, certification in progress 22:03, published by 22:17. This is
  the only row in this table sampled tightly enough to mean anything, and it lands at
  HALF the previous apparent best case -- exactly what Harold predicted when he
  overruled a 20-minute interval. Certification is fast; our records were slow.
- **The old "fast path is ~51 minutes" reading was an artifact.** Submission 15
  shows ~51 minutes submit-to-live, the shortest gap in the set. **Harold, 2026-08-16:
  "I have just never checked it in less than 51 minutes."** That is the key correction
  to how this table reads: every elapsed figure here is bounded below by OBSERVATION
  CADENCE, not by Microsoft. A submission that certified in 15 minutes and was noticed
  at 51 records as 51. Do not treat ~51m as a floor, a typical time, or evidence of how
  fast certification runs -- until a submission is polled continuously, this table
  cannot tell us the real minimum. Submission 17 is the first one polled at a fixed
  10-minute interval specifically to find out.
- **Planning implication**: an evening submission is realistically live within the
  hour, not the next morning. That is now backed by a measurement rather than by the
  gap between two glances at the dashboard.
- **Same-day is the norm, not the exception.** Submissions 10, 13, and 15 all
  certified the same day. Overnight cases (11, 16) are bounded by when someone
  looked, not by Microsoft being slow.
- **Microsoft's own stated SLA is far more conservative**: "a few hours, but in
  some cases up to 3 business days" (Partner Center certification-status panel).
  Our observed times have consistently beaten that, but a single slow submission
  would not be anomalous -- do not promise a release date on the strength of the
  ~51-minute best case.
- **Planning rule of thumb**: a submission uploaded in the evening has usually been
  live by the next morning. Anything tighter than that is luck, not schedule.

## Keeping this current

Add a row at each submission, and fill in the certification column when Harold
confirms it in Partner Center. Two rules:

1. **Never fill the certified column from this file's own guesswork or from
   `.claude/sprint_status.json`** -- both are caches. It gets filled from a direct
   Partner Center observation (screenshot, or Harold saying he checked).
2. Record the recorded-at time honestly, and mark it if the real event clearly
   happened earlier (e.g. an overnight certification noticed at 8am).
3. **Note the polling cadence for each row.** An elapsed time is only as precise as
   the interval it was sampled at; a row observed once the next morning says almost
   nothing about certification speed.

To measure a submission precisely, note the Partner Center "Last modified"
timestamp on the submission when it flips to Publishing/live rather than relying on
when it was noticed here.
