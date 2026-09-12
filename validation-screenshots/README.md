# Manual Validation screenshots

**This folder is deliberately NOT in git.** `.gitignore` excludes everything under it except
this README, so the convention survives even though the images do not.

Harold, 2026-09-11: *"I would like to keep a history of them in the directory, but not in the
repo."*

## Where to put things

```
validation-screenshots/
  sprint-69/
    f209-import-error-cut-off.png
    f210-export-dialog-dark.png
  sprint-70/
    ...
```

One folder per sprint. Name the file after **what it shows**, not when it was taken -- a
timestamp tells nobody anything a year later, and the file date is already on disk.

## Why not in the repo

Phone screenshots run 1-3 MB each and git history never forgets a binary. A sprint's worth
would add more weight to every future clone than the whole source tree. The store-listing
images under `docs/store-assets/` ARE tracked, because those are product assets that ship.
These are working evidence.

## Why not thrown away either

Before this folder existed, validation screenshots lived only in the chat session and were gone
when it ended. What survived was the prose in the backlog cards -- which is usually the more
useful artifact, but it leaves nothing to re-examine when a description turns out to be wrong.

F214 is the live example: it was diagnosed from a tester's sentence and the layout code, and the
card records that nobody re-read the image, because there was no image to re-read.

## How Claude uses this

**Read them, do not merely cite them.** A card that says "see the screenshot" is worth nothing
if the screenshot is not attached to the reasoning.

And the standing rule from Sprint 68 (CLAUDE.md): **a screenshot proves STATE, never CAUSE.**
An image captured after the user acted cannot distinguish "the app did this" from "Harold did
this". When an artifact is consistent with two explanations and one of them flatters the app,
the screenshot is exhausted as evidence -- go to the source.

When a card is written from an image here, cite it by relative path
(`validation-screenshots/sprint-69/f209-import-error-cut-off.png`) so a reader knows the
evidence exists and where to look, even though `git log` will never show it.
