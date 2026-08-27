# MyEmailSpamFilter Privacy Policy

**Effective date**: [SET AT PUBLICATION -- Harold approval required first (GP-5 R-5)]
**Applies to**: the MyEmailSpamFilter application on all platforms (Windows, Android).

## The short version

MyEmailSpamFilter runs entirely on your device. We do not operate any server. We do not
collect, transmit, receive, sell, or share any of your data. Your email is accessed only by
the app running on your own device, using credentials you provide, solely to filter spam
according to rules you control. Uninstalling the app removes everything.

## Who we are

MyEmailSpamFilter is published by Kimmey Consulting - Ohio. Contact:
[CONTACT EMAIL -- Harold to confirm at publication].

## What the app accesses, and why

The app connects to your email account(s) -- using your own credentials -- to evaluate
messages against spam-filtering rules that live on your device:

- **Gmail accounts** connect through Google sign-in (OAuth). The app requests Gmail
  permissions solely to read message headers and content for rule evaluation and to move or
  delete messages according to your rules.
- **Other providers (for example AOL)** connect over IMAP using an app password you supply.

Message evaluation is header-first: most messages are evaluated from their headers (sender,
subject) alone; a message body is retrieved only when one of your body rules requires it,
and is discarded after evaluation.

## What is stored, and where

Everything the app stores lives ONLY on your device:

- **Credentials** (OAuth tokens, app passwords): stored in your operating system's protected
  credential storage.
- **Your filtering rules and safe-sender lists**: stored in a local database, fully under
  your control.
- **Scan results and history**: stored in a local database. This includes, per evaluated
  message: sender address, subject, folder, the action taken, and -- for messages awaiting
  your review -- a short body preview (at most 100 characters). Full message bodies are
  never stored.
- **App settings**: stored locally.

Scan results are retained on your device until you delete them. Nothing is uploaded
anywhere: the app has no backend, no analytics, no crash reporting, no advertising, and no
third-party tracking of any kind.

## Google API Services -- Limited Use disclosure

MyEmailSpamFilter's use and transfer to any other app of information received from Google
APIs will adhere to the
[Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy),
including the Limited Use requirements. Specifically: Gmail data is used only to provide the
app's user-facing spam-filtering features on your device; it is never transferred to anyone,
never used for advertising, and never reviewed by any human.

## Data sharing

We share data with no one. The only network connections the app makes are to your own email
provider (Google, or your IMAP provider) to read and act on your mailbox at your direction.

## Deleting your data

- **Remove an account in the app**: deletes that account's credentials, scan history, and
  settings from your device.
- **Uninstall the app**: your operating system removes all app data.

Because no data ever leaves your device, there is nothing for us to delete on any server.

## Children

The app is not directed at children and provides no content of interest to children; it is a
utility for managing an email account the user already owns.

## Changes to this policy

Material changes will be published at this URL with an updated effective date. Because the
app sends us nothing, changes cannot retroactively affect data -- there is none held by us.

## Contact

Questions about this policy: [CONTACT EMAIL -- Harold to confirm at publication].
