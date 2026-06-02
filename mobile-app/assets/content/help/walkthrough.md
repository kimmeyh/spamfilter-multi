A step-by-step first-time walkthrough to get your email spam filtering up and running.

## Step 1: Install the App and Sign In

Download and install My Email Spam Filter on your device. When you launch the app for the first time, you will see the account selection screen. Choose your email provider (Gmail, AOL, Yahoo, Outlook.com, or ProtonMail) and sign in with your credentials.

If you want to explore the app without signing in to a real email account, select Demo Mode. Demo Mode uses a sample inbox with pre-loaded demo emails so you can try all features without touching your actual email.

## Step 2: Run a Demo Scan

After you sign in, navigate to the Manual Scan screen. If you selected Demo Mode, the app is already loaded with sample emails. Tap "Start Scan" to run your first scan in read-only mode. Read-only mode performs a dry run: it reports what the app would delete or move, but changes nothing.

Watch the scan progress. When it completes, the Results screen shows which emails were matched by the default rules, grouped by action (delete, move, or no rule). This gives you a feel for how the scanner works without any risk.

## Step 3: Run a Read-Only Manual Scan with Move-Matched Target

Return to the Manual Scan Settings. Set the scan mode to read-only (the default). For the "Move matched emails to folder" setting, choose a destination folder where the app can place matched emails (for example, a temporary test folder or your Trash folder). This way, instead of deleting matched emails immediately, the scanner will report and prepare to move them.

Run another scan by tapping "Start Scan". Review the Results screen. Notice that emails are now grouped by action: "Will be moved to [Folder]" for matched emails and "No rule" for unmatched ones. This is still a dry run, so nothing is actually moved yet.

## Step 4: Tune Safe Senders and Rules from the Results

Look at the results on the Results screen or Scan History. If you see legitimate emails grouped with spam (for example, a mailing list or notification sender you actually want), do not let the current rules delete or move them.

Open the Manage Safe Senders screen and add those senders as safe senders. A safe sender is a whitelist: it is checked before any rule, and a match bypasses every block rule. Use the Exact Email type for a single address or Entire Domain to trust a whole domain (including subdomains).

If you see spam that was not caught, open the Manage Rules screen and add a new block rule. The app provides a guided Add Block Rule screen where you choose a rule type and enter the sender information. The app will create the appropriate regex pattern for you, so you do not have to write regex manually unless you want to.

The recommendation hierarchy for rule types, in order of preference, is:

- **Entire Domain** (input `example.com`): the best choice for most spam. Blocks the domain and all of its subdomains. This is the general best because it stops spam from that domain without being so broad that it catches legitimate mail.
- **Exact Email** (input `spam@example.com`): the best choice for transactional senders or when you want to block one specific address only. Matches only that one address, so it is safe and surgical.
- **TLD** (input `.xyz`): the last resort. Blocks every sender ending in that top-level domain (like `.xyz` or `.tk`). This is heavy-handed because it stops mail from every domain using that TLD, including legitimate senders you have never seen. Use it only for a TLD that is overwhelmingly spam in your inbox.

## Step 5: Set Up Daily Background Scanning

Once you have configured your rules and safe senders to your liking, enable background scanning in Settings. Background scanning automatically scans your email once per day on a schedule you set. After the scan completes, the app stores the results so you can review them the next time you open the app.

This means you do not have to manually run a scan every day. Just open the app and view the Scan History to see what the background scanner found. You can then review matched emails, tune rules further, and let the background scanner work in the background.

## Step 6: Process Ongoing No-Rule Emails and Tune Your Rules

When you first enable scanning, your inbox may contain many old emails that do not match any of your rules. These accumulate in the "No rule" category. To gradually process them, the scan window (daysBack setting) controls how far back the scanner looks. For example, if you set daysBack to 30, the scanner only examines emails from the last 30 days. Emails older than that window are skipped, so your first few scans will not revisit the entire history of your inbox.

As you scan and refine your rules, you will catch more spam and fewer emails will fall into the "No rule" category. When you are ready to be more aggressive, you can switch from read-only mode to move-matched or delete-matched mode so the app actually deletes or moves matched emails instead of just reporting what it would do. The Scan History screen includes a progress indicator (labeled F82 in the app code) that shows you how many no-rule emails remain in the current daysBack window, so you can track your progress as you add rules and re-scan.

Revisit your rules regularly. If a particular sender keeps appearing in the "No rule" category and you do not want their mail, add a block rule. If legitimate mail is being caught, add the sender as a safe sender. The app learns from your feedback and becomes more accurate over time.
