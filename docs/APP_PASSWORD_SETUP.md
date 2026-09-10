# App-Specific Password Setup: Yahoo Mail and iCloud Mail

For connecting MyEmailSpamFilter to Yahoo Mail or iCloud Mail. Both providers require an
**app-specific password** -- a separate password generated for one application. Your normal
account password will not work.

Verified against each vendor's own documentation on **2026-09-09**. Where a vendor does not
document something, this page says so rather than guessing: an instruction that sounds
confident and is wrong costs more than one that admits a gap.

---

## Yahoo Mail

### Generate the password

1. Sign in at **https://login.yahoo.com/account/security**
2. Under **External connections**, click **Create app password**
3. Enter a name (for example `MyEmailSpamFilter`)
4. Click **Generate password**
5. **Copy the password immediately** -- it is shown once
6. Click **Done**

### Two-step verification is NOT required (verified 2026-09-09)

**Widely-repeated advice says you must enable 2-step verification first. That is wrong, and it
was tested directly on this account.**

Harold generated a working app password with **2SV turned OFF**, signing in with his password
alone, and the resulting password authenticated a real IMAP scan. So the option is available
without 2SV.

This matters because Yahoo's own documentation does not answer the question either way, and
nearly every third-party guide asserts the requirement. The claim appears to be stale advice
from an earlier era, carried forward. **Do not turn on 2SV just to get app passwords.**

If "Create app password" is genuinely missing, the likelier causes are Yahoo's own warnings
below -- a browser it does not recognise, or a private window -- not a missing 2SV setting.

### Settings the app uses

Server `imap.mail.yahoo.com`, port `993`, SSL required. Username is your **full** Yahoo
address including the domain (`@yahoo.com`, `@ymail.com`, `@rocketmail.com`, or a regional
variant such as `@yahoo.co.uk`).

The app already has the server and port built in. You supply the address and the app password.

### What the password looks like

Yahoo documents it only as a "randomly generated code" -- no length or format is published.
In practice it is **16 lowercase letters**. **Copy and paste it, and remove any spaces.** That
advice is safe whichever way Yahoo displays it.

### Things that trip people up

- **Yahoo app passwords survive a main-password change.** Changing your Yahoo password does
  NOT invalidate them; you must delete them explicitly. (This is the opposite of Apple.)
- **If a password that used to work stops working**, Yahoo's guidance is to delete it and
  generate a new one -- not to retype the old one.
- **Use a browser you have signed into Yahoo with before**, and not a private/incognito
  window. Yahoo warns that a fresh browser can cause friction when creating app passwords.
- **Yahoo blocks some outdated clients by default**, so a rejected sign-in is not always a
  wrong password.
- **Ignore the "IMAP is being discontinued" search results.** Yahoo's SLN36636 is about
  external mailboxes that Yahoo Mail pulls in FROM other providers. It does not apply to a
  third-party client connecting TO Yahoo, and it does not mention app passwords at all.

---

## iCloud Mail

### Before you start -- two hard requirements

**1. Two-factor authentication is required.** Apple states this outright: "To generate and use
app-specific passwords, your Apple Account must be protected with two-factor authentication."
Without 2FA the option is simply not available. This is documented and not negotiable.

**2. You must already have an @icloud.com email address.** This is the one that catches
people, and it is worth reading twice.

If your Apple Account uses a non-Apple address (a Gmail address, say) and you have never set
up iCloud Mail, **you have no iCloud mailbox** -- and Apple says so: "You must create a
primary iCloud email address on your iPhone, iPad, Mac, or iCloud.com before you can use
iCloud Mail."

**Generating an app-specific password will still succeed**, because that is an Apple Account
feature independent of Mail. Then the connection fails, and it looks like a password problem.
It is not.

### How to find out whether you already have one

**The definitive test: go to icloud.com/mail and sign in with your Apple Account.**

- A mailbox opens -> you have an iCloud address. Find the exact address under **Settings**
  (gear icon) -> your account.
- You see a **"Create Email Address"** prompt instead -> you do NOT have one yet, and that
  prompt is how you create it.

That test is definitive because Apple's documentation does not say where the address is
displayed, and does not state whether an Apple Account whose ID is a third-party address (AOL,
Gmail) has a mailbox at all. Rather than infer, just ask iCloud Mail.

Two quicker checks that can confirm a YES but cannot prove a NO:

- **account.apple.com -> Personal Information -> Reachable At** lists any @icloud.com, @me.com
  or @mac.com address you own.
- **iPhone/iPad: Settings -> [your name] -> iCloud -> iCloud Mail.** If it is on, the address
  is shown.

**Do not look only for `@icloud.com`.** Apple (support.apple.com/en-us/118230): accounts created
on or after **September 19, 2012** get `@icloud.com`; accounts created BEFORE that date have
both `@me.com` and `@icloud.com`; and qualifying legacy accounts have `@mac.com` as well. An
older account's mailbox may be sitting there under a domain you were not looking for.

### To create the address

- **iPhone/iPad**: Settings -> [your name] -> iCloud -> iCloud Mail, then follow the prompts
- **Mac**: System Settings -> [your name] -> iCloud -> Mail, turn on sync, follow the prompts
- **Web**: icloud.com/mail -> Create Email Address

**Choose carefully: Apple does not let you delete or rename this address afterward.**

iCloud+ (paid) is **not** required for a plain @icloud.com address. It is only needed for a
custom email domain -- and if your address is on a custom domain, letting iCloud+ lapse breaks
that mail.

### Generate the password

1. Sign in at **https://account.apple.com**
2. In the **Sign-In and Security** section, select **App-Specific Passwords**
3. Select **Generate an app-specific password** and follow the prompts
4. Name it (for example `MyEmailSpamFilter`)
5. **Copy the password immediately**

You can have up to **25** active app-specific passwords.

### Settings the app uses

Server `imap.mail.me.com`, port `993`, SSL required.

**The username is unusual and this is the second-most-common failure.** Apple documents the
IMAP username as "usually the name of your iCloud Mail email address (for example,
johnappleseed, **not** johnappleseed@icloud.com)" -- the part before the @ only. Apple adds
that if that does not connect, try the full address.

So: **try the local part first, then the full address.**

### What the password looks like

Apple does not document the format. In practice it is **16 lowercase letters in four
hyphen-separated groups**: `abcd-efgh-ijkl-mnop`.

**Paste it with the hyphens first.** Apple's own services accept that form. Only if
authentication fails, retry with the hyphens removed.

### Things that trip people up

- **Changing your Apple Account password revokes ALL app-specific passwords automatically.**
  Apple documents this. If mail suddenly stops working, ask whether the Apple password
  changed recently. (Opposite of Yahoo.)
- **If you see an SSL error**, Apple suggests trying TLS instead.
- **iCloud Mail does not support POP** -- IMAP only. The app uses IMAP.

---

## The two providers behave OPPOSITELY -- do not carry advice across

| | Yahoo | iCloud |
|---|---|---|
| Main password change | app passwords **survive** | app passwords **all revoked** |
| Separators | remove spaces | **keep** the hyphens (first attempt) |
| 2FA/2SV required | **NO** -- tested with 2SV off, 2026-09-09 | **required**, documented |
| Username for IMAP | full address | local part first, then full address |
| Mailbox exists by default | yes | **no** -- needs an @icloud.com address first |

**Generating a password successfully does not prove the connection will work.** For iCloud
that is the missing-mailbox trap above. For Yahoo it can be client-reputation blocking. If
sign-in fails, check those before assuming the password was mistyped.

## Sources

- Yahoo: [Generate and manage 3rd-party app passwords (SLN15241)](https://help.yahoo.com/kb/account/generate-manage-rd-party-passwords-sln15241.html) -- no publication date shown
- Yahoo: [Mail server settings (SLN4075)](https://help.yahoo.com/kb/SLN4075.html)
- Yahoo: [Ways to securely access Yahoo Mail (SLN27791)](https://help.yahoo.com/kb/SLN27791.html)
- Apple: [Sign in with app-specific passwords (102654)](https://support.apple.com/en-us/102654) -- published 2025-10-08
- Apple: [iCloud Mail server settings (102525)](https://support.apple.com/en-us/102525) -- published 2026-02-03
- Apple: [Create a primary email address for iCloud Mail](https://support.apple.com/guide/icloud/create-a-primary-icloudcom-email-address-mmdd8d1c5c/icloud)

**Note on freshness**: Apple's pages carry publication dates and state their requirements
explicitly. Yahoo's carry no dates at all and are silent on the 2SV question -- so the Yahoo
2SV answer here does not come from Yahoo at all. It comes from a direct test on a real account
(2026-09-09, 2SV off, password-only sign-in, app password generated and used for a successful
IMAP scan). A tested negative beats an undocumented assumption, and it beats the near-unanimous
third-party advice that says the opposite.
