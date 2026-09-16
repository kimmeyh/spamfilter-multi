# Sprint 70 validation screenshots

Not in git (see `../README.md`). This index IS tracked, because a description
outlives the image.

| File | Shows | Card |
|---|---|---|
| `Screenshot_20260916_100743.png` | Gmail Sign-In screen after the F211 console fix. Red "Sign-In Error" panel: `PlatformException(null_intent, Failed to authorize: Null intent received, , null)`. Harold accepted all four consent screens first. | **F219** |
| `Screenshot_20260916_100752.png` | The same screen scrolled, showing the full error plus the Privacy & Security panel. | **F219** |

## Why these two matter

They are the evidence that **F211's console fix WORKED**. The error changed from
`Error 400: invalid_request` -- Google refusing the client outright -- to
`null_intent`, which is raised only after the consent flow completes and the
response fails to get back into the app.

A different error at a later stage is progress, not a repeat failure. That
distinction is why the screenshots are worth keeping: without them, "still
broken" would read as "the fix did nothing."
