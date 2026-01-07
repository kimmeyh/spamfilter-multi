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

Windows and Android:
Need to be able to really add Bulk Mail folder
Need to be able to find all folders
Need to be able to actually find safe senders and/or moved, and rules that apply and if would have been deleted.

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
  Can you review the code base and last commit to determine if updates are needed to the following files, then make updates as needed:
  - D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
  - d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md

  When complete (NOT before unless Critical for success), update:
  - D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
  - d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
  - d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md

Proceed to draft the changes in the files for review and testing.

-------Common parts used in prompts-------------------
Can you write a commit message for the current files modified and ready for commit?

Please close the Android app.

Please build the Android app using the following script, |||powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -InstallToEmulator"|||, monitor its progress by monitoring logs, then help address any issues.

Please run the app using the following script, |||powershell -NoProfile -ExecutionPolicy Bypass -Command "cd D:\Data\Harold\github\spamfilter-multi\mobile-app\scripts; .\build-with-secrets.ps1 -BuildType debug -Run"|||, monitor its progress
via log file, then while I test can you monitor the progress of the Android application via |||adb logcat|||, then help address any issues that I report.

Can you review the modified files for phase 3.2 and 3.3, determine if updates are needed to the following files, then make updates as needed:
- D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
- d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
- d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
- d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md

Can you initiate a PR for all commits in this branch to the develop branch with appropriate PR description referencing any Issues resolved.

Can you review the code base and last commit to determine if updates are needed to the following files, then make updates as needed:
- D:\Data\Harold\github\spamfilter-multi\CLAUDE.md
- d:\Data\Harold\github\spamfilter-multi\memory-bank\memory-bank.json
- d:\Data\Harold\github\spamfilter-multi\memory-bank\mobile-app-plan.md
- d:\Data\Harold\github\spamfilter-multi\mobile-app\README.md



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
Completed:

  The install of flutter is incorrect.  Can you save any key configuration files (backup), then remove all the files in d:\dev\flutter directory, then re-install flutter to the directory.  Restore any configuration files, as needed.
