A step-by-step first-time walkthrough to get your email spam filtering up and running.

## Step 1: Install the App and Sign In

Download and install My Email Spam Filter on your device. When you launch the app for the first time, you will see the account selection screen. Choose your email provider (Gmail, AOL, Yahoo, Outlook.com, or ProtonMail) and sign in with your credentials.

If you want to explore the app without signing in to a real email account, select Demo Mode. Demo Mode uses a sample inbox with pre-loaded demo emails so you can try all features without touching your actual email.

## Step 2: Run a Demo Scan

After you sign in, navigate to the Manual Scan screen. If you selected Demo Mode, the app is already loaded with sample emails. Tap "Start Scan" to run your first scan in read-only mode. Read-only mode performs a dry run: it reports what the app would delete or move, but changes nothing.

Watch the scan progress. When it completes, the Results screen shows which emails were matched by the default rules, grouped by action (delete, move, or no rule). This gives you a feel for how the scanner works without any risk.

## Step 3: Add Your First Email Account

Ready to move beyond Demo Mode? Add a real email account. Tap the Select Account icon to open the Accounts screen, then tap the "+" button to add an account. Gmail (Google Mail) and AOL are the most tested providers; Yahoo, Outlook.com, and ProtonMail are also supported.

For Gmail, an App Password (IMAP) with 2-Step Verification enabled is the recommended sign-in method; Google Sign-In (OAuth) is available as an alternative. For AOL and other IMAP providers, enter your email address and an app password generated from the provider's security settings, not your regular account password.

## Step 4: Run a Read-Only Manual Scan with Move-Matched Target

Return to the Manual Scan Settings. Set the scan mode to read-only (the default). For the "Move matched emails to folder" setting, choose a destination folder where the app can place matched emails (for example, a temporary test folder or your Trash folder). This way, instead of deleting matched emails immediately, the scanner will report and prepare to move them.

Run another scan by tapping "Start Scan". Review the Results screen. Notice that emails are now grouped by action: "Will be moved to [Folder]" for matched emails and "No rule" for unmatched ones. This is still a dry run, so nothing is actually moved yet.

## Step 5: Tune Safe Senders and Rules from the Results

Look at the results on the Results screen or Scan History.

Click the "Deleted" bullet to filter by only the emails that will be automatically deleted. If you see legitimate emails that show as deleted, but you would like to keep receiving them, click the email, then choose Add to Safe Senders and select "Exact Email", "Exact Domain", or "Entire Domain" as appropriate.

Click the "Safe" bullet to filter by only emails marked as safe, which will be kept in your inbox. If an email shows as safe but is actually spam, click the email, then choose Create Block Rule and select "Block Email", "Block Exact Domain", or "Block Entire Domain" as appropriate.

Click the "No rule" bullet to filter by emails that have no rule associated with them yet, and select the first email in the list:

- If the email is clearly spam, create a rule to block future emails from that sender. Choose Create Block Rule and select "Block Email", "Block Exact Domain", or "Block Entire Domain" as appropriate.
- If the email is clearly good, create a rule to mark future emails from that sender as safe. Choose Add to Safe Senders and select "Exact Email", "Exact Domain", or "Entire Domain" as appropriate.
- If you are unsure, you can look in your own email to investigate: copy the sender's address, search your inbox for it, review the emails you find, then return to the app to decide.
- If you are still unsure, tap Skip and move on to the next email.

After you create a rule, the app re-evaluates the remaining "No rule" list against it and updates the list, so any other emails the new rule covers are addressed automatically.

**Notes on Safe Sender rule types:**

- **Exact Email** (input `spam@example.com`): the best choice for people you know, transactional senders, or when you want to mark only one specific address as safe. Matches only that one address, so it is safe and surgical. This is the HIGHLY recommended way to mark safe sender addresses from large email providers (gmail.com, yahoo.com, hotmail.com, outlook.com, msn.com, icloud.com, aol.com, comcast.com, att.net, and similar) -- you likely have both safe senders and spam senders using the same provider, so you do not want to trust the whole provider domain. The app shows a recommendation to use Exact Email whenever it recognizes a well-known provider domain.
- **Exact Domain** (input `example.com`): often the best choice for a company's own mail. Marks the domain (not its subdomains) as safe. This is a good middle ground when you trust a specific sending domain without needing to trust every subdomain under it.
- **Entire Domain** (input `example.com`): often the best choice for larger organizations, such as your bank, that send from multiple subdomains. Marks the domain and all of its subdomains as safe.

**Notes on Block Rule types:**

- **Block Email** (input `spam@example.com`): the HIGHLY recommended way to block a specific address from a large email provider (gmail.com, yahoo.com, hotmail.com, outlook.com, msn.com, icloud.com, aol.com, comcast.com, att.net, and similar) -- you likely have both safe senders and spam senders using the same provider, so blocking the whole provider domain would also block mail you want. Matches only that one address, so it is safe and surgical. The app shows a recommendation to use Block Email whenever it recognizes a well-known provider domain.
- **Block Entire Domain** (input `example.com`): the best choice for most spam. Blocks the domain and all of its subdomains. This is the general best choice because it stops spam from that domain without being so broad that it catches legitimate mail from an unrelated domain. In testing, the large majority of the time you want to block a domain, you want to block the entire domain -- with a few exceptions.
- **Block Exact Domain** (input `example.com`): the best choice for some spam. Blocks the domain but not its subdomains. Useful when a specific subdomain sends mail you still want -- for example, you may want mail from `email.example.com` but not from `info.example.com`.

You can also manage safe senders and block rules directly from Settings > General, without needing a scan result to start from -- see Step 6.

## Step 6: Tune Safe Senders and Rules from Settings

Open Settings > General > Manage Safe Senders to add, update, or delete safe senders directly, without needing a scan result to work from. A safe sender is a whitelist: it is checked before any rule, and a match bypasses every block rule.

Open Settings > General > Manage Rules to add, update, or delete block rules directly. The app helps build the correct regex pattern for you, so you do not need to write regex by hand unless you want to.

Manage Rules is also the only place to manage the app's set of Top-Level Domains (TLDs) used by TLD-type block rules. A TLD is the last part of a domain -- for example, `.com` is a TLD, and so is a country-code TLD like `.au`. Nearly every domain under most non-U.S.-oriented TLDs is spam to a typical U.S. inbox, so a large set of TLDs is blocked by default.

You can remove any TLD from the blocked set, or add additional ones. If you regularly do business or personal communication with people whose addresses fall under a blocked TLD, removing that TLD is one option -- but adding Safe Sender rules for the specific individual emails, domains, or entire domains you actually want is usually the better approach, since it keeps the rest of that TLD blocked.

## Step 7: Set Up Daily Background Scanning

Once you have configured your rules and safe senders to your liking, enable background scanning in Settings. Background scanning automatically scans your email once per day on a schedule you set. After the scan completes, the app stores the results so you can review them the next time you open the app.

This means you do not have to manually run a scan every day. Just open the app and view the Scan History to see what the background scanner found. You can then review matched emails, tune rules further, and let the background scanner work in the background.

## Step 8: Process Ongoing No-Rule Emails and Tune Your Rules

When you first enable scanning, your inbox may contain many old emails that do not match any of your rules. These accumulate in the "No rule" category. To gradually process them, the scan window (daysBack setting) controls how far back the scanner looks. For example, if you set daysBack to 30, the scanner only examines emails from the last 30 days. Emails older than that window are skipped, so your first few scans will not revisit the entire history of your inbox.

As you scan and refine your rules, you will catch more spam and fewer emails will fall into the "No rule" category. When you are ready to be more aggressive, you can switch from read-only mode to move-matched or delete-matched mode so the app actually deletes or moves matched emails instead of just reporting what it would do. The Scan History screen includes a progress indicator (labeled F82 in the app code) that shows you how many no-rule emails remain in the current daysBack window, so you can track your progress as you add rules and re-scan.

Revisit your rules regularly. If a particular sender keeps appearing in the "No rule" category and you do not want their mail, add a block rule. If legitimate mail is being caught, add the sender as a safe sender. The app learns from your feedback and becomes more accurate over time.
