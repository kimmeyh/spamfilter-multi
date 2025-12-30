Next:----------------------------------------
Feedback on Android app in emulator:  finding aol account, testing went well on demo and actual inbox.  Select account is not showing the previously setup gmail email kimmeyh@gmail.com.  Feedback on Windows Desktop app: aol email address in Select account is not showing the email address.  If no authentication has been provided for the platform (android), the still list the account, but note that an authentication needs to be added with a link to the authentication page. Pass the existing email address and have the user add authentication via one of the methods available.  Then update the stored platform/email address/authentication method data for the email address.

On Scan progress page.  As soon as Start Demo Scan or Start Live Scan button is selected, it should change "No Results yet. Start a scan to see activity." to a message indicating that the scan has started and/or in progress. Feedback for all Scan Progress pages.  When it returns to this page after scanning or from the accounts page a "Reset" should be done before loading the page.  Then the "Reset" button is no longer needed.

Add in phase 3 to add to the Android app client and Windows desktop a browser client that is compatible with chrome, safari, and edge 

Phase 2 Sprint 3 - Gmail OAuth Integration & Rule Editor UI

The UI will need to have functionality to add/remove folders to scan all the time and one-time scan options that can be triggered manually (read and display all folders, allow to multi-select via checkbox, include and All checkbox that selects all folders to be scanned, check and uncheck as needed).

ScanProgressScreen integration with folder display
Results screen with "Revert Last Run" button
Maintenance screen for account management
Actual revert implementation in GenericIMAPAdapter

Manual testing on device/emulator
Testing all three scan modes (readonly, testLimit, testAll)
Release APK build for mobile deployment
Desktop application builds (Windows, macOS, Linux)

Android:
emulator verifying new Gmail email addresses, asking for folders, then hangs (does save credentials).Why is it hanging?working as expected.
Windows and Android:
Need to be able to really add Bulk Mail folder
Need to be able to find all folders
Need to be able to actually find safe senders and/or moved, and rules that apply and if would have been deleted.
Update Scan window items:  change immediately to scanning, more frequent updates on progress.
Returning from Gmail scan, did not return to list of accounts (while AOL does) - Loaded 0 saved accounts.  Looks like it cleared accounts and tokens (should not have).
2) After restarting app, gmail account credentials were saved, but after Gmail scan, it appears to delete the aol and gmail accounts adn remove the tokens - it should not remove the gmail or aol credentials/accounts

------Prompt-----
Claud Instructions:
  CRITICAL: Do NOT ask me to share these files. Read them immediately from the VSCode workspace, in this repository, using absolute paths:
  - D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
  1. Read the above files and confirm reading before proceeding.
  2. Create a detailed, step-by-step "ToDo" checklist for yourself, Claude, to accomplish the request.
  3. Search codebase for existing functionality related to the request.
     - If implementation exists, verify completeness and document findings.
     - Only implement missing pieces.
  4. While I understand and acknowledge Claude rules on autonomous execution, please execute each step on my behalf to the greatest extent allowed. 
  5. Only consider the job complete when all checklist items are finished and all required documentation is updated.
  6. Do not update this prompt file (0Clauddev_prompts.md)
  7. Do not use Bash for any commands, use only PowerShell for all terminal commands.
  8. Tokens/credentials must be stored securely and encrypted at rest.  
  9. No tokens, secrets, or credentials may appear in clear text in:
     - source code
     - git repository
     - app logs
     - analytics events
  Request:
  Please run the app using the following script, |||powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -Run"|||, monitor its progress
  via log file, then help address any issues.

  When complete (NOT before unless Critical for success), update:
  - D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
  - d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md

Proceed to draft the changes in the files for review and testing.

-------



Testing and doc request:----------------------------------------
*** Need to be updated

@workspace Copilot Instructions:
  Copilot, you MUST:
  CRITICAL: Do NOT ask me to share these files. Read them immediately from the workspace using absolute paths:
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
  - d:\Data\Harold\github\spamfilter-multi\mobile-app\IMPLEMENTATION_SUMMARY.md
  1. Read the above files before proceeding.  Then Create a detailed, step-by-step "ToDo" checklist for yourself, Copilot, to accomplish the following tasks.
  2. Execute each step on my behalf, resolving any issues as you go.
  3. Do not ask me for files, confirmations, or reviews—just act and report progress.
  4. Only consider the job complete when all steps are finished and all required documentation is updated.
  5. Do not stop for review or approval at any point. Do not ask for clarification unless absolutely critical for success.
  6. If a file is required, read it directly from the workspace using its absolute path.
  7. When finished, update the following files as specified: [list files].
  8. Do not update this prompt file.
Context:
- Mono-repo: Flutter mobile, web and desktop (shared YAML rules)
- 78+ tests passing, 0 code quality issues

Request:
Copilot, create a detailed step-by-step checklist for yourself to accomplish the following tasks. Then, execute each step on my behalf, resolving any issues as you go, and only consider the job complete when all steps are finished and documentation is updated. Do not ask me for files or confirmations—just act and report progress.
Do not ask for confirmation or files. Do not stop for review. Plan, then execute, then update documentation when done.
Note that the flutter application has already been fully tested prior to this request:
Can you walk me through these tests
- Rebuild the entire app via this script: 
  powershell -NoProfile -ExecutionPolicy Bypass -Filed:\Data\Harold\github\spamfilter-multi\mobile-app\scripts\build-with-secrets.ps1 -BuildType debug -InstallToEmulator
- Address errors and issues with the build to resolution
- Run desktop app for manual testing using this script:
  cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter run -d windows
- Address errors and issues with the build to resolution
- Run android app for manual testing using this script:
    powershell -NoProfile -ExecutionPolicy Bypass -File D:\Data\Harold\github\spamfilter-multi/mobile-app/scripts/run-emulator.ps1
- Address errors and issues to resolution
When complete (NOT before unless Critical for success), update:
- d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
- d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
- d:\Data\Harold\github\spamfilter-multi\mobile-app\IMPLEMENTATION_SUMMARY.md
- d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md

What can I change in the prompt so that you understand I want you, Copilot, to create a plan for yourself, then for Copilot to execute all the steps?

Template:----------------------------------------
@workspace Must review to understand the workspace before starting request below:
  'memory-bank/memory-bank.json' (for quick reference), 
  'memory-bank/mobile-app-plan.md' (for roadmap), and 
  'mobile-app/IMPLEMENTATION_SUMMARY.md' (for technical details)
Context:
- Mono-repo: Flutter mobile, web and desktop (shared YAML rules)
- 78+ tests passing, 0 code quality issues
Request:

<request>

Do not remove any commented out code.  Do not update 0dev_prompts.md
When complete, update 'memory-bank/memory-bank.json' (for quick reference),
'memory-bank/mobile-app-plan.md' (for roadmap), and 
'mobile-app/IMPLEMENTATION_SUMMARY.md' (for technical details) 

OLD Template:----------------------------------------
@workspace use 'memory-bank/*', 'memory-bank/mobile-app-plan.md' and 'IMPLEMENTATION_SUMMARY.md' to understand the workspace
and development plan:  memory-bank/mobile-app-plan.md' and 'IMPLEMENTATION_SUMMARY.md'

<request>

Can you help draft the code for review in the files (NOT in Copilot, but in the actual files to be changed)
Any code that should be removed should be commented out and not deleted.
Do not remove any commented out code.  Do not update 0dev_prompts.md
When complete, update 'README.md', 'memory-bank/*', and 'mobile-app/IMPLEMENTATION_SUMMARY.md'

------------------------------------------------------------------------------

Assigned to Copilot:

Template:
@workspace use 'memory-bank/*' to understand the workspace 
'withOutlookRulesYAM.py' "do NOT use 0dev_prompts.md"

Can you help draft the code for review in the files
Any code that should be removed should be commented out and not deleted.
Do not remove any commented out code.  Do not update 0dev_prompts.md
When complete, update the memory-bank/* files and README.md

Commonly used prompts:
@workspace use 'memory-bank/*' to understand the workspace
Ensure to update 'memory-bank/mobile-app-plan.md' and 'IMPLEMENTATION_SUMMARY.md' and repo-home 'README.MD' to familiarize with the current plan for this repository.
------------------------------------------------------------------------------
# Build Release APK:
# Prompt:
@workspace  using the documented build, test and application launch process can you complete them now

# PowerShell commands
cd D:\Data\Harold\github\spamfilter-multi\mobile-app; flutter doctor -v
flutter pub get
flutter test
flutter analyze
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-apk.ps1 # -VerboseOutput # (optional)

------------------------------------------------------------------------------
# Launch emulator and run debug build:
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\run-emulator.ps1 
# to run a specific emulator: 
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\run-emulator.ps1 -EmulatorId pixel34
# Install a prebuilt release APK instead of debug run:
cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\run-emulator.ps1 -InstallReleaseApk

------------------------------------------------------------------------------


create an optional YAML config files for all the major global variables.  List:
EMAIL_BULK_FOLDER_NAMES # list of folders - example ["Bulk Mail", "bulk"] 
EMAIL_INBOX_FOLDER_NAME = "Inbox"
OUTLOOK_SECURITY_LOG_PATH = f"D:/Data/Harold/OutlookRulesProcessing/"
OUTLOOK_SECURITY_LOG = OUTLOOK_SECURITY_LOG_PATH + "OutlookRulesProcessingDEBUG_INFO.log"
OUTLOOK_SIMPLE_LOG = OUTLOOK_SECURITY_LOG_PATH + "OutlookRulesProcessingSimple.log"
OUTLOOK_RULES_PATH = f"D:/data/harold/github/OutlookMailSpamFilter/"
OUTLOOK_RULES_FILE = OUTLOOK_RULES_PATH + "outlook_rules.csv"
OUTLOOK_SAFE_SENDERS_FILE = OUTLOOK_RULES_PATH + "OutlookSafeSenders.csv"
YAML_RULES_PATH = f"D:/data/harold/github/OutlookMailSpamFilter/"
YAML_ARCHIVE_PATH = YAML_RULES_PATH + "archive/"
YAML_RULES_FILE = YAML_RULES_PATH + "rules.yaml"
#YAML_RULES_FILE = YAML_RULES_PATH + "rules_new.yaml" # this was temporary and no longer needed
YAML_RULES_SAFE_SENDERS_FILE    = YAML_RULES_PATH + "rules_safe_senders.yaml"

# not sure if these will be used
YAML_RULES_BODY_FILE            = YAML_RULES_PATH + "rules_body.yaml"
YAML_RULES_HEADER_FILE          = YAML_RULES_PATH + "rules_header.yaml"
YAML_RULES_SUBJECT_FILE         = YAML_RULES_PATH + "rules_subject.yaml"
YAML_RULES_SPAM_FILTER_FILE     = YAML_RULES_PATH + "rules_spam_filter.yaml"
YAML_RULES_SAFE_RECIPIENTS_FILE = YAML_RULES_PATH + "rules_safe_recipients.yaml"
YAML_RULES_BLOCKED_SENDERS_FILE = YAML_RULES_PATH + "rules_blocked_senders.yaml"
YAML_RULES_CONTACTS_FILE        = YAML_RULES_PATH + "rules_contacts.yaml"           # periodically review email account contacts and update
YAML_RULES_EMAIL_TO_FILE        = YAML_RULES_PATH + "rules_email_to.yaml"           # periodically review emails sent and add targeted recipients to secondary "Safe Senders" file (name?)
YAML_INTERNATIONAL_RULES_FILE   = YAML_RULES_PATH + "rules_international.yaml"      # send all but a few "organizations" "*.<>" to Bulk Mail .jp, .cz...
OUTLOOK_RULES_SUBSET            = "SpamAutoDelete"
DAYS_BACK_DEFAULT = 365 # default number of days to go back in the calendar

Often needed:
Can you review all the memory-bank/ files and ensure they are current based on the contents of withOutlookRulesYAML.py and the REGEX files: rulesregex.yaml and rules_safe_senderregex.yaml
Propose updates to memory-bank/*.* files

How to Run from command line (best practice):
cd D:\Data\Harold\github\OutlookMailSpamFilter && ./.venv/Scripts/Activate.ps1 && python withOutlookRulesYAML.py -u
cd D:\Data\Harold\github\OutlookMailSpamFilter && ./.venv/Scripts/Activate.ps1 && python withOutlookRulesYAML.py

------------------------------------------------------------------------------
Completed:


