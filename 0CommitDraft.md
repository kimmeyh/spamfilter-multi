
Role:
You are a highly paid scrum master and development team for the following application:

## Executive Summary

The spamfilter-multi application is a background application that reviews emails in a users email addresses account and uses rules to determine if they are safe-senders, or known spam emails or neither.

The team is tasked with determining the features to accomplish the phase 3.5 goals and what can/should be accomplished in each sprint. After reading the CLUADE.MD file and the below development goals and details, please ask clarifying questions as needed.

## Development Phases
### Goals for next Sprint or Sprints: Planning for management of identified spam
1) Processing Scan Results - build the backend and UI
2) User Application Settings - build the backend and UI

Please see the attached CLAUDE.MD file and the below background information:
The management of identified spam will be similar between email providers, but will likely have differences.  Like the rest of the app, we would like to email providers and platforms behave the same way and use the same code whenever reasonably possible, but different when needed or unreasonable to do the same way.

Background - App functionality in human terms:
  - The Safe Senders list identifies regex email addresses that the user has identified as OK to see and wants to make sure they are always in the inbox for review.  They can be broken down into a few sets:
    1. Very specific email addresses from individuals
    2. Very specific from business partners
    3. Business partner emails where the "<first-level-domain>.<top-level-domain>" match, but can match any <sub-domain> of "<address-name>@<sub-domain>.<first-level domain>.<top-level-domain>".
    4. - Business partner emails where the "<first-level domain>.<top-level-domain>" match, but can match any <sub-domain> of "<any-address-name>@<sub-domain>.<first-level-domain>.<top-level-domain>".
    5. Since the Safe-Senders check is primary (if they are safe, they are still safe even if they match a auto-delete rule), we need a way to add exceptions to Safe-Senders of type 2 and 3

Background - Other Rule Sets:
- Rule sets are primarily for taking action to delete and/or move and/or flag emails
  - Anything matching a rule with an action should be tagged
  - They are matched by Regex patterns based on the
    - Message Header "From:" - matching of content of information in the header copy of From
      - This is the most accurate way to find unwanted emails (majority of the rules)
      - Why - hard to spoof the header copy of "From:" while easy to spoof the message copy of "From:"
      - Regex patterns are similar to Safe-Senders 1-4
        - types 1 and 2 are rarely marked as spam incorrectly and should be tagged uniquely.
        - types 3 and 4 are rate, but more likely to be incorrect and should be tagged uniquely.
      - Some care needs to be taken in the content of the header "From:" to make it easy to match
        - convert to all lowercase and regex match lowercase 
        - remove all special characters and spaces so it only contains [0-9], [a-z], underscore and hyphen.
        - did I miss anything?
    - Message Header content (not including Message Header "From:")- free form match of anything in the message header   
    - Message "Subject:" content
      - Harder to match as all kinds of things can be added to mask
      - Some care needs to be taken in the content of the header "From:" to make it easy to match
        - convert to all lowercase and regex match lowercase 
        - remove all special characters [0-9], [a-z], underscore, period, exclamation point, single and double quotes, brackets, angle brackets and squiggly brackets, ampersand, dollar sign, parenthesis and hyphen.
        - did I miss anything?
      - These could match a good message so they should be tagged uniquely
    Message "Body" content
      - Harder to match as all kinds of things can be added to mask
      - Some care needs to be taken in the content of the header "From:" to make it easy to match
        - convert to all lowercase and regex match lowercase 
        - remove all special characters [0-9], [a-z], underscore, period, exclamation point, single and double quotes, brackets, angle brackets and squiggly brackets, ampersand, dollar sign, parenthesis and hyphen.
        - Most of these are looking for similar regex patterns as domains as they are looking for URL's in the body
          - While it is often true that the Header "From:" has the same domain <first-level domain>.<top-level-domain> and are better of as Header "From:" rules.  Sometimes they are different and putting them here is helpful.
          - There are a few text strings that often show up in undesirable email messages, but rarely, if ever, show up in desired emails. 
          - The two 'SpamAutoDeleteBody-imgur.com' rules can be re-incorporated into the Message "Body" content rules and removed as it's own ruleset.
        - did I miss anything?
      - These could match a good message so they should be tagged uniquely

Background - There are 2 types of scans:
- Background scans:
  - happen every <n> minutes (user selections on a setting screen). This scan scans all user default selected folders for every provider/email address they have enabled (each will have a user selectable "enable background scans" in their settings screen(s)).  This never processes auto-delete, auto-move and safe-sender processing for any matching rules, it flags emails that did not match any rules and keeps a list for later processing, but does not move or delete them.
  - continues to use flag in settings for each provider/email address for "Scan Mode: Read=Only"
- On demand/manual scans that automatically processing rules, but not process emails with unmatched rules (run it expecting no user input at the end).
  - These scans can be read-only and not process any rules, but keep track o what was found and what has / has ot be en processed.

Processing Scan Results details:
- The scan should save a list of unprocessed items from last background scan and last manual scan requested by the user 
  - Should include all the information currently available in Scan Results
  - Every time a background scan runs, it should create a new list of unprocessed items.  At the successful completion of the scan, it should remove the previous list from the prior background scan. This leaves only one list of background scan unprocessed items.
  - Every time a manual scan runs, it should create a new list of unprocessed items.  At the successful completion of the scan, it should remove the previous list from the prior background scan. This leaves only one list of manual scan unprocessed items.

UI for processing scan results:
What is needed at the end of a scan as an enhancement to "View Results" and so the user can select to process scan results (prior or new manual scan) at any time.
  - Looks for last run (on manual/on demand or background scan) for provider/email address, then presents UI to process them (similar to current View Results" screen, but with enhancements)
- On demand scans with processing results and emails with unmatched rules
1. The user needs to both review the results
  - One wrapped line (similar to current) to include:
    - Email folder it currently is stored in <folder-name>
    - Header "From:" email address (filtered or adjusted as necessary so that it is viewable)
    - email "Subject:" (filtered or adjusted as necessary so that it is viewable)
  - a way to see:
    - the header
    - the message body
      - ability for the app to find domain references for links in the body
    - 
2. The user needs to be able to indicate:
  - additions to the Safe Sender list:  
    - specific email addresses (ex. John.doe@aol.com)
    - specific domains (ex. @email.ibm.com)
    - wildcard/regex of domains:
      - '^[^@\s]+@(?:[a-z0-9-]+\.)*5hourenergy\.com$'
  - additions to the AutoDelete Rules, including:
      - additions to auto delete from Header "From:" by:
        - specific email addresses (ex. 'abdwhab1997th@gmail\.com')
        - specific domains (ex. '@(?:[a-z0-9-]+\.)*acquia\.com$' )
        - wildcard/regex of domains. examples:
          - '@(?:[a-z0-9-]+\.)*acquia\-sites\.[a-z0-9.-]+$'
          - '@.*\.ac$'
      - additions to Message Header content rules (not including Message Header "From:")
        - free form match of anything in the message header 
      - additions to Message "Subject:" content rules
        - free form match of anything in the message header 
      - additions to Message "Body:" content rules
        - free form match of anything in the message header. Examples:
          - '800\-571\-7438'
          - 'audacious,\ llc'
          - 'coinbase\ global'
        - any URL found in the body of the message where the user can select to add:
          - specific domains (ex. @email.ibm.com)
          - wildcard/regex of domains:
            - '^[^@\s]+@(?:[a-z0-9-]+\.)*5hourenergy\.com$'
            - '/accountryside\.com$'
  - Please add to the dart database of rules a "date added" field so that each rule added can be found by date
  - New rules can be enabled when user selects to add them

User Application Settings details:

  - on the "Select Account" page need to add a settings button (#android #w11desktop #alluis) that goes to the Settings for the entire app
  - Settings for the entire app.  Categories:
    - Manual Scan defaults
      - Scan Mode: 
        - Read-Only (checkbox), 
        - Process safe senders (checkbox)
        - Process rules (checkbox for All).  Separate checkboxes for:
          - Auto Delete Header From
          - Auto Delete Header Text
          - Auto Delete Sender From
          - Auto Delete Subject Text
          - Auto Delete Body Text
          - Auto Delete Body URL domains
      - Select folders to scan
        - uses current functionality to find all folders 
    - Background scans defaults
      - defaults for all future newly added provider/email addresses
        - Every <n> minutes
        - Scan Mode: (same as for Manual Scan Defaults above)
    - Provider/email addresses setups
      - Authentication
      - Background scans
        - Every <n> minutes
        - Scan Mode: (same as for Manual Scan Defaults above)
  - on the "Scan Progress - <provider> Mail" screen need to add a settings button - goes to Settings > Provider/email addresses setup

Clarifications:
  - For manual scan: you wrote that unmatched-rule emails are not processed and “run it expecting no user input at the end.” Do you want unmatched items stored for manual scans too (so user can process later), or only for background scans?
    - keep one un-matched-rule emails scan results per scan type: manual, background
  - If a scan fails mid-run, what should be kept?
    - Yes, keep last prior successful unmatched-rule scan results until the next successful scan completes of each type (manual, background). No need to keep partial results.
  - What is the canonical message identifier per provider so that each email in the unmatched-rule emails scan results can be easily accessed for processing?
    - Can you determine what the best practice way to do this for each provider (currently AOL and Gmail) and then use this as initial approach.
  - When viewing “unprocessed” items later, should the UI detect if the message moved/deleted externally and show “missing”?
    - If scan results are immediately processed, no check for moved/deleted is needed. However, if processing at a future time, a check on each unmatched email should be done to see if it still exists in the folder specified in the scan results. If no longer there, do not list. Immediately process as many as needed to fit on the users screen (changes per device and UI (desktop, android)) while processing all others in the background so when the user scrolls updated results will be shown.
  - For Safe-sender exceptions (your item #5) - For “exceptions to Safe-Senders type 2 and 3”: 
     - this should be modeled as determine it is a safe sender per 1-4, then process the “safe-sender denylist” list last with anything matching causing the Safe-Sender flag to be turned off.
  - When user clicks “Add AutoDelete…”, do we create a rule entry in rules.yaml with the appropriate condition bucket
    - We can transition to dart database of rules and no longer use rules.yaml or rules_safe_senders.yanl
    - A rule entry in the dart database should be made for each AutoDelete rule and each Safe Sender rule when selected by the user
  - For Subject/Body normalization, do you want to preserve: Unicode letters (non-English), emoji, and common punctuation like : / ? that appear in URLs and tracking strings?
    - Requirement is to save strings without these and match without these.  Ex: reallybadword rule should match "rea?llly.bad?word". Can you also have it match "rea!1y bad   word?" with tabs replace by spaces, all spaces reduced to 1 or removed and replacing punctuation replacing letters counted as letters - try normally, try with spaces removed, try with typical letters replaced: examples: l replaced by ! or 1 / e replaced by 3
  - For Header From: normalization, do you want to preserve plus-addressing (user+tag@domain) or normalize it?
    - if the rule matches with or without the tagging it should be counted as matching











