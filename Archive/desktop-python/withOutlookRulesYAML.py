#------------------List of future enhancements------------------


# ----------------------------------------------------
# (not in this order, probably later) Convert from using win32com to using o365
# ***Review an dupdate before starting
#
# Change to a phone app that processes emails from cloud provider email accounts:  aol, gmail, yahoo, etc.
#   - Start with aol email accounts
#   - in a language that can be used on all platforms:  Android, iOS, Windows, Mac, Linux
#   - use the same YAML rules file for all platforms
#   - use the same YAML rules file for all email accounts
#   - use the same YAML rules and allow uniqueness for different email accounts and account/folder combinations
#   - allow for multiple email accounts to be processed
#   - allow for each email account, allow multiple folders to be processed
#   - Allow options similar to Outlook Junk options: junk level (Safe Lists Only/High/Low/No automatic filtering - see Outlook window
#   - Allow for option to notify of emails with suspicious domain names in email addresses and links in the body
#   - Add a curated, updated list of suspicious domain names, why, level...
#   - Parameterize some of the variables so they can be:
#       - Saved to a file
#       - Read from a file
#       - Updated by a standars process: OUTLOOK_RULES_SUBSET
#       OUTLOOK_RULES_PATH, OUTLOOK_RULES_FILE, EMAIL_ADDRESS, EMAIL_FOLDER_NAME, OUTLOOK_SECURITY_LOG,
#       OUTLOOK_SIMPLE_LOG, DAYS_BACK_DEFAULT, DEBUG_EMAILS_TO_PROCESS...
# Implement different processing rules for different folders?
# Create a summary report of processed emails?

#------------------Change Log------------------
# 01/24/2025 Harold Kimmey All working as expected
# 02/10/2025 Harold Kimmey Completed move to www.github.com/kimmeyh/spamfilter.git repository
# 02/17/2025 Harold Kimmey Updated _process_actions to accurately pull the assign_to_category value by searching it as an object
# 03/28/2025 Harold Kimmey Exported rules to JSON so that they can be maintained in a separate YAML file (the can be transferred between machines and platforms (Windows, Mac, Linux, Android, iOS, etc.))
#   Spam filter rules - done
#   Safe Senders - done
#   Safe recipients - done (was empty)
#   Blocked Senders - very small and were added manually to Outlook Rules - spam body# 03/30/2025 Harold Kimmey Added export and import of YAML rules
# 04/01/2025 Harold Kimmey Verified export of rules from Outlook to YAML file (at exit) matches rules from import of YAML file
# 04/01/2025 Harold Kimmey Switch to using YAML file as import instead of Outlook rules
# 04/01/2025 Harold Kimmey Committed changes, pushed, PR to Main branch of kimmeyh/spamfilter.git
# 05/13/2025 Harold Kimmey Current Status
#   - All rules are being read from the YAML file
#   - All rules are being written to the YAML file at the end of the run successfully
#   - All safe_sender rules are being read from the YAML file
#   - All safe_sender rules are being written to the YAML file (updated)
#   - Removed checks for updates to rules and safe_senders - instead will save copies to Archive for each run
#   - Update Output of rules.yaml - ensure they are written as compatible with regex strings  (double quoted, sorted, no duplicates)
#   - Output of safe_senders.yaml - ensure they are written as compatible with regex strings (double quoted), sorted, and unique
#   - Updated Output of rules.yaml - ensure each rule is sorted, and unique
# 05/19/2025 Harold Kimmey - Updates for feature/userinputheader
# 07/03/2025 Harold Kimmey - Add memory-bank to repository to enhance Github Copilot suggestions
# 07/04/2025 Harold Kimmey - Updated EMAIL_BULK_FOLDER_NAME to EMAIL_BULK_FOLDER_NAMES list, added "bulk" folder, updated processing to handle multiple folders
# 07/05/2025 Harold Kimmey - Added second-pass email reprocessing after rule updates for enhanced cleanup
#       - Add updates to rules for emails not deleted
#           for each email not deleted
#               show details of the email:  subject, from in header, URL's in the body
#                   Suggest to add new domains (based on from in header) to the header rules
#                   If N to header rule, suggest body rules
#                   If no body rules added, suggest subject rules
#                   Full commit after each of the above changes
#       - Change folder to process to be a list of folders, add "bulk", change process to process a list of folders
#       - Reprocess all emails in the EMAIL_BULK_FOLDER_NAMES folder list a second time, in case any of the remaining emails can no be moved or deleted.
#       - Move backup files to a archive/"backup directory"
#       - Update mail processing to use safe_senders list for all header exceptions
#  08/25/2025 Harold Kimmey - Update so that it can run with no input by default.  New flag -u -update to update via user input
#  10/09/2025 Harold Kimmey - Updates to convert code to regex patterns and update rules.yaml and rules_safe_senders.yaml to REGEX
#       - Update to consider all Header, Body, Subject, From, lists strings to be regex patterns
#       - create updated rules.yaml with all regex strings as rulesregex.yaml
#       - Create updated rules_safe_senders.yaml with all regex strings as rules_safe_sendersregex.yaml
#       - Independent program that reads all rules.yaml entries and if missing adds them to rulesregex.yaml
#       - Independent program that reads all rules_safe_senders.yaml entries and if missing adds them to rules_safe_sendersregex.yaml
#       - Need to analyze and change all rules.yaml strings to regex patterns.
#       - Update all new regex in rules.yaml to use wildcards
#       - Update all new regex in rules_safe_senders.yaml to use wildcards
#       - Updated rules_safe_senders.yaml to all be regex pattern
#       - update entries for "@<sub-domain>.ibm.com" to "@*.ibm.com" regex patterns
# 10/10/2025 Harold Kimmey - Updated all memory-bank files and README.md
# 10/14/2025 DEPRECATION - Legacy YAML file support removed:
#       - Commented out --use-legacy-files CLI flag (kept for reference)
#       - Commented out all legacy_match() functions in process_emails() and second-pass processing
#       - Updated set_active_mode() to always use regex files (parameter kept for backward compatibility)
#       - Updated test_mode_selection.py to reflect regex-only mode
#       - Updated memory-bank/cli-usage.md and memory-bank/processing-flow.md
#       - Updated README.md to indicate legacy files are deprecated
#       - Regex mode is now the only supported mode (rulesregex.yaml and rules_safe_sendersregex.yaml)
#       - Legacy files (rules.yaml and rules_safe_senders.yaml) are no longer used
#       - All legacy code commented out with DEPRECATED 10/14/2025 markers for reference
# 10/18/2025 Harold Kimmey - Enhanced interactive rule filtering during user input:
#       - Fixed prompt_update_rules() to use regex matching for newly added rules and safe senders
#       - Replaced literal string checks with _compile_pattern_list() and _regex_match_header_any()
#       - Emails matching newly added domain rules (d) or safe domain rules (sd) are now properly skipped
#       - Updated memory-bank/processing-flow.md and README.md to document the enhancement
# 11/10/2025:
#       - Renamed rulesregex.yaml back to rules.yaml
#       - Renamed rules_safe_sendersregex.yaml back to rules_safe_senders.yaml
#       - Updated all code references to use consolidated filenames
#       - Files now contain regex patterns (legacy mode deprecated 10/14/2025)
#------------------General Documentation------------------
#
# See README.md and memory-bank/*.md files for detailed documentation

#Imports for python base packages
import re
from datetime import datetime, timedelta
import logging
import sys
import json
import os
import yaml
import copy
import traceback
import argparse

# Code update timestamp: 2025-07-17 21:15:00
print("Loading withOutlookRulesYAML.py - updated 2025-07-17 21:15:00")

#Imports for packages that need to be installed
# Handle win32com.client import gracefully for testing environments
try:
    import win32com.client
    WIN32COM_AVAILABLE = True
except ImportError:
    # This allows tests to run in environments without win32com (e.g., Linux, macOS, CI/CD)
    # while maintaining full functionality when win32com is available (Windows with Outlook)
    WIN32COM_AVAILABLE = False
    win32com = None

try:
    import IPython
except ImportError:
    IPython = None

# Settings:
DEBUG = False # True or False
INFO = False if DEBUG else True #If not debugging, then INFO level logging
DEBUG_EMAILS_TO_PROCESS = 100 #100 for testing

CRLF = "\n"
EMAIL_ADDRESS = "kimmeyharold@aol.com"
# EMAIL_BULK_FOLDER_NAME = "Bulk Mail"  # Commented out - now using list below
EMAIL_BULK_FOLDER_NAMES = ["Bulk Mail", "bulk"]  # Changed from single folder to list of folders
EMAIL_INBOX_FOLDER_NAME = "Inbox"
WIN32_CLIENT_DISPATCH = "Outlook.Application"
OUTLOOK_GETNAMESPACE = "MAPI"
OUTLOOK_SECURITY_LOG_PATH = f"D:/Data/Harold/OutlookRulesProcessing/"
OUTLOOK_SECURITY_LOG = OUTLOOK_SECURITY_LOG_PATH + "OutlookRulesProcessingDEBUG_INFO.log"
OUTLOOK_SIMPLE_LOG = OUTLOOK_SECURITY_LOG_PATH + "OutlookRulesProcessingSimple.log"
OUTLOOK_RULES_PATH = f"D:/Data/Harold/github/OutlookMailSpamFilter/"
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
CRLF = "\n"             # Carriage return and line feed for formatting


def print_to(message, to_log=False, to_simple=False, to_console=False, log_instance=None):
    """
    Print message to multiple destinations based on parameters.
    
    Args:
        message (str): Message to print
        to_log (bool): If True, write to debug/info log via log_print method
        to_simple (bool): If True, write to simple log file (OUTLOOK_SIMPLE_LOG)
        to_console (bool): If True, write to console (stdout)
        log_instance: Instance of OutlookSecurityAgent for accessing log_print method
    
    Example:
        print_to("Processing email...", to_log=True, to_simple=True, to_console=True, log_instance=agent)
        print_to("User message", to_console=True)
    """
    # Sanitize message for logging
    try:
        sanitized_message = re.sub(r'[^\x00-\x7F]+', '', message)
    except (TypeError, AttributeError):
        sanitized_message = str(message)
    
    # Write to logging module via log_print method
    if to_log and log_instance:
        try:
            log_instance.log_print(sanitized_message)
        except Exception as e:
            # Fallback if logging fails
            if to_console:
                print(f"Logging error: {str(e)}")
    
    # Write to simple log file
    if to_simple and OUTLOOK_SIMPLE_LOG:
        try:
            with open(OUTLOOK_SIMPLE_LOG, 'a') as f:
                f.write(sanitized_message + '\n')
        except Exception as e:
            if to_console:
                print(f"Simple log write error: {str(e)}")
    
    # Write to console
    if to_console:
        print(sanitized_message)

# Backward compatibility wrapper - maintains existing simple_print behavior
def simple_print(message):
    """Backward compatibility wrapper for simple_print - uses print_to"""
    if OUTLOOK_SIMPLE_LOG:
        print_to(message, to_simple=True)
    else:
        print_to(message, to_console=True)

class OutlookSecurityAgent:
    def __init__(self, email_address=EMAIL_ADDRESS, folder_names=EMAIL_BULK_FOLDER_NAMES, debug_mode=DEBUG, test_mode=False):
        r"""
        Initialize the Outlook Security Agent with specific account and folders

        Args:
            email_address: Email address of the account to process
            folder_names: List of folder names to process
            debug_mode: If True, run in simulation mode with verbose output
            test_mode: If True, allow initialization without finding Outlook folders (for testing)
        """
        self.debug_mode = debug_mode
        self.test_mode = test_mode
        
        # Check if win32com is available before trying to use it
        if not WIN32COM_AVAILABLE:
            # Allow class instantiation for testing purposes without Outlook functionality
            self.outlook = None
            self.namespace = None
            print("Warning: win32com.client not available. Outlook functionality disabled.")
        else:
            self.outlook = win32com.client.Dispatch(WIN32_CLIENT_DISPATCH)
            self.namespace = self.outlook.GetNamespace(OUTLOOK_GETNAMESPACE)

        # Default file paths
        self.YAMO_RULES_PATH = YAML_RULES_PATH  # Set appropriate default path
        self.YAML_RULES_FILE = YAML_RULES_FILE  # Now points to rules.yaml (regex patterns)
        self.YAML_SAFE_SENDERS_FILE = YAML_RULES_SAFE_SENDERS_FILE  # Now points to rules_safe_senders.yaml (regex patterns)

        # Active files used for all reads/writes; main() will set these based on CLI flags
        self.active_rules_file = self.YAML_RULES_FILE
        self.active_safe_senders_file = self.YAML_SAFE_SENDERS_FILE

        # Configure logging
        log_format = '%(asctime)s - %(levelname)s - %(message)s'
        logging.basicConfig(
            level=logging.DEBUG if debug_mode else logging.INFO,
            format=log_format,
            handlers=[
                logging.FileHandler(OUTLOOK_SECURITY_LOG),
                # logging.StreamHandler(sys.stdout)  # Also print to console
            ]
        )
        self.log_print(f"\n=============================================================\nStarting new run")
        self.log_print(f"Initializing agent for {email_address}, folders: {folder_names}")
        self.log_print(f"Debug mode: {debug_mode}")
        self.log_print(f"Test mode: {test_mode}")

        # Store email address for later use
        self.email_address = email_address

        # Get the specific account's folders - now handling multiple folders with retry logic
        self.target_folders = []
        max_retries = 3
        
        for folder_name in folder_names:
            folder = None
            for retry in range(max_retries):
                folder = self._get_account_folder(email_address, folder_name)
                if folder:
                    break
                elif retry < max_retries - 1:
                    self.log_print(f"Retry {retry + 1}/{max_retries}: Could not find folder '{folder_name}', retrying...")
                    import time
                    time.sleep(0.5)  # Brief delay before retry
            
            if folder:
                self.target_folders.append(folder)
                self.log_print(f"Successfully found folder: {folder_name}")
            else:
                self.log_print(f"Could not find folder '{folder_name}' in account '{email_address}' after {max_retries} attempts")
        
        if not self.target_folders and not test_mode:
            raise ValueError(f"Could not find any of the specified folders {folder_names} in account '{email_address}'")
        elif not self.target_folders and test_mode:
            self.log_print(f"Test mode: No folders found, but continuing (expected in test environment)")
        
        self.inbox_folder = self._get_account_folder(email_address, EMAIL_INBOX_FOLDER_NAME)

        self.rules = []
        self.rule_to_category = {
            "SpamAutoDeleteBody":           "SpamBody",
            "SpamAutoDeleteBody-imgur.com": "SpamImgur",
            "SpamAutoDeleteFrom":           "SpamHeader",
            "SpamAutoDeleteHeader":         "SpamHeader",
            "SpamAutoDeleteSubject":        "SpamSubject"
        }

    def build_domain_regex_from_address(self, addr_or_domain: str) -> str:
        r"""
        Build a domain regex anchored on the first meaningful subdomain below the TLD.

        Output form:
            '@(?:[a-z0-9-]+\.)*<anchor>\.[a-z0-9.-]+$'

        Where <anchor> is chosen by scanning left from the TLD to find a label that:
          - is not a common infra label (www, mail, smtp, ...), and
          - is at least 3 chars (to avoid overly-generic anchors), and
          - matches [a-z0-9-]+

        Example desired behavior:
            Description of desired outcome: '@<any sub-domain>.<any-subdomain...>.<specific sub-domain, ex "google">.<any sub-domain>.<any-subdomain...>.<any top-level domain>" 
                          should result in: '@(?:[a-z0-9-]+\.)*google\.[a-z0-9.-]+$'
        """
        s = (addr_or_domain or '').strip().lower()

        # Extract domain portion
        if s.startswith('@'):
            domain = s[1:]
        elif '@' in s:
            domain = s.split('@', 1)[1]
        else:
            domain = s

        domain = domain.strip('.')
        labels = [lbl for lbl in domain.split('.') if lbl]

        # Fallbacks
        if len(labels) == 0: #complete failure to find base domain as desired
            self.log_print(f"Could not find any specific sub-domain in: {addr_or_domain}")
            return addr_or_domain
        if len(labels) == 1:
            anchor = labels[0]
            self.log_print(f"Found selected highest sub-domain in add domain request: {re.escape(anchor)} from: {addr_or_domain}")
            return f"@(?:[a-z0-9-]+\\.)*{re.escape(anchor)}\\.[a-z0-9.-]+$"

        SKIP_LABELS = {
            'www', 'mail', 'smtp', 'mx', 'ns', 'cdn', 'img', 'static', 'assets',
            'api', 'dev', 'test', 'stg', 'stage', 'beta',
            'co', 'com', 'net', 'org', 'gov', 'edu', 'mil', 'biz', 'info',
            'news', 'shop', 'store', 'support'
        }

        anchor = None
        for i in range(len(labels) - 2, -1, -1):
            candidate = labels[i]
            if candidate and candidate not in SKIP_LABELS and re.fullmatch(r'[a-z0-9-]{3,}', candidate):
                anchor = candidate
                break
        if not anchor:
            anchor = labels[-2]
                    
        self.log_print(f"Found selected highest sub-domain in add domain request: {re.escape(anchor)} from: {addr_or_domain}")
        return f"@(?:[a-z0-9-]+\\.)*{re.escape(anchor)}\\.[a-z0-9.-]+$"

    def build_sender_domain_safe_regex(self, addr_or_domain: str) -> str:
        r"""
        Build a regex that matches any email at the sender's domain, with any number of subdomains.

        Example output for lifeway.com:
            '^[^@\s]+@(?:[a-z0-9-]+\.)*lifeway\.com$'

        Inputs can be:
          - full email (user@lifeway.com)
          - domain with leading '@' (@lifeway.com)
          - bare domain (lifeway.com)
        """
        s = (addr_or_domain or '').strip().lower()
        if s.startswith('@'):
            dom = s[1:]
        elif '@' in s:
            dom = s.split('@', 1)[1]
        else:
            dom = s
        dom = dom.strip('.')
        if not dom:
            return ''

        # Reduce to registrable domain (SLD + TLD), with a small set of common multi-part public suffixes.
        labels = [p for p in dom.split('.') if p]
        base = dom
        if len(labels) >= 2:
            # Common multi-part public suffixes. Extend as needed.
            MULTI_PART_SUFFIXES = {
                'co.uk', 'ac.uk', 'gov.uk', 'org.uk',
                'com.au', 'net.au', 'org.au',
                'com.br', 'com.cn', 'co.jp'
            }
            last2 = '.'.join(labels[-2:])
            if last2 in MULTI_PART_SUFFIXES and len(labels) >= 3:
                base = '.'.join(labels[-3:])  # e.g., example.co.uk
            else:
                base = '.'.join(labels[-2:])  # e.g., cursor.com

        # Anchor: any local part, then any number of subdomains, then the registrable domain
        # return f"^[^@\\s]+@(?:[a-z0-9-]+\\.)*{re.escape(dom)}$"  # prior behavior (kept for reference)
        return f"^[^@\\s]+@(?:[a-z0-9-]+\\.)*{re.escape(base)}$"

    def set_active_mode(self, use_regex_files: bool):
        r"""Set active read/write files based on desired mode and log the selection.
        Args:
            use_regex_files: If True, use regex-specific YAML files; else use legacy files.
        """
      
        # Always use consolidated YAML files now (regex patterns only)
        self.active_rules_file = YAML_RULES_FILE
        self.active_safe_senders_file = YAML_RULES_SAFE_SENDERS_FILE
        self.log_print(f"Operating mode: REGEX (only supported mode)")
        self.log_print(f"Using rules file: {self.active_rules_file}")
        self.log_print(f"Using safe_senders file: {self.active_safe_senders_file}")

    def convert_safe_senders_yaml_to_regex(self, source_file=YAML_RULES_SAFE_SENDERS_FILE, dest_file=None):
        r"""Convert safe_senders.yaml entries into regex-compatible patterns and write to parallel file.
        
        DEPRECATED 10/18/2025: This utility is no longer needed as files now use consolidated regex filenames.

        - Treat '*' as glob wildcard -> '.*'
        - Escape other regex metacharacters
        - Keep lowercase, sorted, unique via export_safe_senders_to_yaml
        - Create backups via export method
        """
        try:
            # If no dest_file specified, overwrite source (in-place conversion)
            if dest_file is None:
                dest_file = source_file
                
            src = self.get_safe_senders_rules(source_file)
            patterns = src.get("safe_senders", []) if isinstance(src, dict) else []

            def to_regex(p: str) -> str:
                if not isinstance(p, str):
                    p = str(p)
                raw = p.strip().lower()
                # Preserve wildcard semantics for '*': replace temporarily, escape, then restore
                placeholder = "__WILDCARD__"
                raw = raw.replace('*', placeholder)
                escaped = re.escape(raw)
                # Restore wildcard as '.*'
                escaped = escaped.replace(placeholder, ".*")
                return escaped

            converted = [to_regex(p) for p in patterns]

            # Build document structure compatible with export
            out_doc = {"safe_senders": converted}

            # Reuse export to normalize (lowercase, deduplicate, sort) and back up, writing to dest_file
            ok = self.export_safe_senders_to_yaml(out_doc, rules_file=dest_file)
            if ok:
                self.log_print(f"Converted {len(converted)} safe_senders to regex and wrote {dest_file}")
            else:
                self.log_print(f"Failed to write converted safe_senders to {dest_file}")
            return ok
        except Exception as e:
            self.log_print(f"Error converting safe_senders to regex: {str(e)}")
            return False

    def log_print(self, message, level="INFO"):
        try:
            sanitized_message = self._sanitize_string(message)
            logging.debug(sanitized_message) if level == "DEBUG" else None
            logging.info(sanitized_message) if level == "INFO" else None

        except UnicodeEncodeError:
            logging.debug(sanitized_message.encode('utf-8', 'replace').decode('utf-8')) if level == "DEBUG" else None
            logging.info(sanitized_message.encode('utf-8', 'replace').decode('utf-8'))  if level == "INFO" else None
        except Exception as e:
            self.log_print(f"Error: {str(e)}")
        return

    def _sanitize_string(self, s):
        r"""Sanitize string to replace non-ASCII characters"""
        try:
            return re.sub(r'[^\x00-\x7F]+', '', s)
        except UnicodeEncodeError:
            return re.sub(r'[^\x00-\x7F]+', '', s.encode('utf-8', 'replace').decode('utf-8'))

    def _get_account_folder(self, email_address, folder_name):
        r"""Get a specific folder from a specific email account"""
        self.log_print(f"Searching for folder: {folder_name} in account: {email_address}", "DEBUG")

        try:
            # Loop through accounts to find the matching one
            for account in self.outlook.Session.Accounts:
                self.log_print(f"Checking account: {account.SmtpAddress}", "DEBUG")

                if account.SmtpAddress.lower() == email_address.lower():
                    self.log_print(f"Found matching account: {account.SmtpAddress}")

                    # Get the root folder for this account
                    root_folder = self.namespace.Folders(account.DeliveryStore.DisplayName)
                    self.log_print(f"Accessed root folder: {root_folder.Name}", "DEBUG")

                    # Search for the target folder
                    try:
                        # Try direct access first
                        target_folder = root_folder.Folders[folder_name]
                        self.log_print(f"Found target folder directly: {folder_name}")
                        return target_folder
                    except Exception:
                        self.log_print(f"Folder not found directly, searching recursively...")
                        return self._find_folder_recursive(root_folder, folder_name)

            self.log_print(f"Account not found: {email_address}")
            return None

        except Exception as e:
            self.log_print(f"Error finding account folder: {str(e)}")
            return None

    def _find_folder_recursive(self, root_folder, folder_name):
        """Recursively search for a folder by name"""
        try:
            # Search in all subfolders
            for folder in root_folder.Folders:
                if folder.Name == folder_name:
                    self.log_print(f"Found target folder recursively: {folder_name}")
                    return folder
                # Recursively search in subfolders
                found_folder = self._find_folder_recursive(folder, folder_name)
                if found_folder:
                    return found_folder
        except Exception as e:
            self.log_print(f"Error in recursive folder search: {str(e)}")
        return None

    def _escape_pattern(self, value):
        """Escape special characters in values for CSV storage"""
        if not isinstance(value, str):
            return value, False
        needs_special = False
        if any(char in value for char in [',', '"', "'", '\\', '\n', '\r', ';']):
            needs_special = True
            value = value.replace('\\', '\\\\').replace('"', '\\"')
        return value, needs_special

    def _unescape_pattern(self, value):
        """Unescape value from CSV storage"""
        if not isinstance(value, str):
            return value
        return value.replace('\\"', '"').replace('\\\\', '\\')

    def _deep_compare_dicts(self, dict1, dict2, path=""):
        """Recursively compare dictionaries and return specific differences."""
        differences = []

        if not isinstance(dict1, dict) or not isinstance(dict2, dict):
            if dict1 != dict2:
                differences.append({
                    'path': path,
                    'value1': dict1,
                    'value2': dict2
                })
            return differences

        # Keys in dict1 but not in dict2
        for key in dict1:
            if key not in dict2:
                differences.append({
                    'path': f"{path}.{key}" if path else key,
                    'value1': dict1[key],
                    'value2': None
                })
                continue

            # If both have the key, compare values
            if isinstance(dict1[key], dict) and isinstance(dict2[key], dict):
                # Recursive comparison for nested dictionaries
                nested_diffs = self._deep_compare_dicts(
                    dict1[key], dict2[key],
                    f"{path}.{key}" if path else key
                )
                differences.extend(nested_diffs)
            elif isinstance(dict1[key], list) and isinstance(dict2[key], list):
                # Compare lists item by item
                list_diffs = self._deep_compare_lists(
                    dict1[key], dict2[key],
                    f"{path}.{key}" if path else key
                )
                differences.extend(list_diffs)
            elif dict1[key] != dict2[key]:
                differences.append({
                    'path': f"{path}.{key}" if path else key,
                    'value1': dict1[key],
                    'value2': dict2[key]
                })

        # Keys in dict2 but not in dict1
        for key in dict2:
            if key not in dict1:
                differences.append({
                    'path': f"{path}.{key}" if path else key,
                    'value1': None,
                    'value2': dict2[key]
                })

        return differences

    def _deep_compare_lists(self, list1, list2, path=""):
        r"""Compare two lists and return differences."""
        differences = []

        # Check for length differences
        if len(list1) != len(list2):
            differences.append({
                'path': path,
                'value1': f"List length: {len(list1)}",
                'value2': f"List length: {len(list2)}"
            })

        # Compare elements
        for i, (item1, item2) in enumerate(zip(list1, list2)):
            if isinstance(item1, dict) and isinstance(item2, dict):
                nested_diffs = self._deep_compare_dicts(
                    item1, item2,
                    f"{path}[{i}]"
                )
                differences.extend(nested_diffs)
            elif isinstance(item1, list) and isinstance(item2, list):
                nested_diffs = self._deep_compare_lists(
                    item1, item2,
                    f"{path}[{i}]"
                )
                differences.extend(nested_diffs)
            elif item1 != item2:
                differences.append({
                    'path': f"{path}[{i}]",
                    'value1': item1,
                    'value2': item2
                })

        # Handle different length lists
        for i in range(min(len(list1), len(list2)), max(len(list1), len(list2))):
            if i < len(list1):
                differences.append({
                    'path': f"{path}[{i}]",
                    'value1': list1[i],
                    'value2': "Missing"
                })
            else:
                differences.append({
                    'path': f"{path}[{i}]",
                    'value1': "Missing",
                    'value2': list2[i]
                })

        return differences

    def compare_rules(self, rules1, rules2):
        """Compare two sets of rules and return the differences."""
        # Extract rules arrays if wrapped in dictionaries
        if isinstance(rules1, dict) and "rules" in rules1:
            rules1_list = rules1["rules"]
        else:
            rules1_list = [rules1] if isinstance(rules1, dict) else rules1

        if isinstance(rules2, dict) and "rules" in rules2:
            rules2_list = rules2["rules"]
        else:
            rules2_list = [rules2] if isinstance(rules2, dict) else rules2

        # Validate input data types
        if not isinstance(rules1_list, list):
            self.log_print(f"Error: First rule set is not a list or dict. Type: {type(rules1_list)}")
            rules1_list = []
        if not isinstance(rules2_list, list):
            self.log_print(f"Error: Second rule set is not a list or dict. Type: {type(rules2_list)}")
            rules2_list = []

        # Create dictionaries keyed by rule name for easy comparison
        rules1_dict = {}
        rules2_dict = {}

        # Safely create dictionaries with error handling
        for i, rule in enumerate(rules1_list):
            if isinstance(rule, dict) and 'name' in rule:
                rules1_dict[rule['name']] = rule
            else:
                self.log_print(f"Warning: Invalid rule format in first set at index {i}: {type(rule)} - {rule}")
                # Optionally add more detailed debugging
                if isinstance(rule, dict):
                    self.log_print(f"Dictionary keys: {list(rule.keys())}")

        for i, rule in enumerate(rules2_list):
            if isinstance(rule, dict) and 'name' in rule:
                rules2_dict[rule['name']] = rule
            else:
                self.log_print(f"Warning: Invalid rule format in second set at index {i}: {type(rule)} - {rule}")
                # Optionally add more detailed debugging
                if isinstance(rule, dict):
                    self.log_print(f"Dictionary keys: {list(rule.keys())}")

        # Find rules unique to each set
        rules_only_in_1 = set(rules1_dict.keys()) - set(rules2_dict.keys())
        rules_only_in_2 = set(rules2_dict.keys()) - set(rules1_dict.keys())

        # Find modified rules (present in both but different)
        modified_rules = {}
        common_rules = set(rules1_dict.keys()) & set(rules2_dict.keys())
        for rule_name in common_rules:
            # Use deep comparison to identify specific differences
            diffs = self._deep_compare_dicts(rules1_dict[rule_name], rules2_dict[rule_name])
            if diffs:
                modified_rules[rule_name] = {
                    'rules1': rules1_dict[rule_name],
                    'rules2': rules2_dict[rule_name],
                    'differences': diffs
                }

        return {
            'rules_only_in_1': [rules1_dict[name] for name in rules_only_in_1],
            'rules_only_in_2': [rules2_dict[name] for name in rules_only_in_2],
            'modified_rules': modified_rules
        }


    def output_rules_differences(self, rule_set_one, rule_set_one_name, rule_set_two, rule_set_two_name):
        r"""Output the differences between 2 sets of JSON rules"""
        differences = self.compare_rules(rule_set_one, rule_set_two)

        # Print the differences
        self.log_print(f"{CRLF}Differences between Outlook rules and YAML rules:")
        if differences['rules_only_in_1']:
            self.log_print(f"\nRules only in {rule_set_one_name}:")
            for rule in differences['rules_only_in_1']:
                self.log_print(f"- {rule['name']}")
        else:
            self.log_print(f"{CRLF}No rules only in {rule_set_one_name}")

        if differences['rules_only_in_2']:
            self.log_print(f"{CRLF}Rules only in {rule_set_two_name} set:")
            for rule in differences['rules_only_in_2']:
                self.log_print(f"- {rule['name']}")
        else:
            self.log_print(f"{CRLF}No rules only in {rule_set_two_name} set")

        if differences['modified_rules']:
            self.log_print(f"{CRLF}Modified rules:")
            for name, rules in differences['modified_rules'].items():
                self.log_print(f"- {name} has differences")
                # Print the differences between the two rules
                self.log_print(f"  {rule_set_one_name} rule: {json.dumps(rules['rules1'], indent=2)}", DEBUG)
                self.log_print(f"  {rule_set_two_name} rule: {json.dumps(rules['rules2'], indent=2)}", DEBUG)
            return False
        else:
            self.log_print(f"{CRLF}No modified rules found", DEBUG)
            return True

    # NOTE: tried to get the outlook junk email options and lists, but could not get it to work
    # def get_outlook_junk_mail_options(self):
    #     r"""
    #     Retrieve the Outlook Junk Email Options settings (as shown in Outlook Classic > Home > Junk Email Options > Options)
    #     and convert them to a dictionary for further processing or export.
    #     """
    #     timestamp = datetime.now().isoformat()
    #     try:
    #         # Access the JunkEmailOptions directly from the DefaultStore
    #         options = self.outlook.Session.DefaultStore.JunkEmailOptions
    #         # Build a dictionary with key properties.
    #         # (Property names may vary between Outlook versions.)
    #         options_dict = {
    #             'last_modified' : timestamp,
    #             'name'          : "JunkEmailOptions",
    #             'filter_level'  : getattr(options, 'FilterLevel', None),  # e.g., 0=Off, 1=Low, 2=High (depending on your Outlook version)
    #             'enabled'       : getattr(options, 'Enabled', True),  # Some versions may provide an Enabled property
    #             # The safe and blocked lists are typically collections. Convert them to lists if available.
    #             'safe_senders'  : list(options.SafeSenders) if getattr(options, 'SafeSenders', None) else [],
    #             'blocked_senders': list(options.BlockedSenders) if getattr(options, 'BlockedSenders', None) else [],
    #             # Optional: if your Outlook exposes domains lists:
    #             'safe_domains'  : list(options.SafeDomains) if hasattr(options, 'SafeDomains') and options.SafeDomains else [],
    #             'blocked_domains': list(options.BlockedDomains) if hasattr(options, 'BlockedDomains') and options.BlockedDomains else [],
    #         }
    #     except Exception as e:
    #         self.log_print(f"Error processing Junk Email Options: {str(e)}")
    #         return {}
    #     if DEBUG:
    #         self.log_print(f"Junk Email Options retrieved: {options_dict}")
    #     return options_dict # will need to be converted and appended to the json rules object

    def get_outlook_rules(self):    # no longer in use - YAML rules file is used
        r"""
        Convert Outlook rules to JSON format with comprehensive error checking.
        Returns a list of rule dictionaries with all available properties.
        """
        rules_json = []
        rules_dict = {}
        timestamp = datetime.now().isoformat()

        try:
            # Get all rules that start with the subset name
            self.log_print("Importing Outlook rules and converting to JSON format...")
            outlook_rules_raw = self.outlook.Session.DefaultStore.GetRules()
            if outlook_rules_raw is None:
                self.log_print("Error: No rules found in Outlook. Ensure rules are configured.")
                return []
            outlook_rules = [rule for rule in outlook_rules_raw if rule.Name.startswith(OUTLOOK_RULES_SUBSET)]
            self.log_print(f"Processing {len(outlook_rules)} rules...")

            for rule in outlook_rules:
                try:
                    self.log_print(f"\n\nAnalyzing rule: {rule.Name}")
                    rule_dict = {
                        'last_modified': timestamp,
                        "name": rule.Name if hasattr(rule, "Name") else "Unnamed Rule",
                        "enabled": bool(rule.Enabled) if hasattr(rule, "Enabled") else False,
                        "isLocal": bool(rule.IsLocalRule) if hasattr(rule, "IsLocalRule") else False,
                        "executionOrder": rule.ExecutionOrder if hasattr(rule, "ExecutionOrder") else 0,
                        "conditions": {},
                        "actions": {},
                        "exceptions": {},
                    }

                    # Process Conditions
                    if hasattr(rule, "Conditions") and rule.Conditions:
                        conditions = rule.Conditions
                        rule_dict["conditions"] = self._process_conditions(conditions, False)

                    # Process Actions
                    if hasattr(rule, "Actions") and rule.Actions:
                        actions = rule.Actions
                        rule_dict["actions"] = self._process_actions(actions)

                    # Process Exceptions
                    if hasattr(rule, "Exceptions") and rule.Exceptions:
                        exceptions = rule.Exceptions
                        rule_dict["exceptions"] = self._process_conditions(exceptions, True)  # Exceptions use same format as conditions

                    rules_json.append(rule_dict)
                    self.log_print(f"Successfully processed rule: {rule_dict['name']}", "DEBUG")

                except Exception as e:
                    self.log_print(f"Error processing rule {getattr(rule, 'Name', 'Unknown')}: {str(e)}")
                    # Add error information to the rule
                    rules_json.append({
                        "name": getattr(rule, "Name", "Unknown Rule"),
                        "error": str(e),
                        "processed": False
                    })

            return json.loads(json.dumps(rules_json, indent=2, default=str))

        except Exception as e:
            self.log_print(f"Error accessing Outlook rules: {str(e)}")
            return json.dumps({"error": str(e)})

    def get_safe_senders_rules(self, rules_file=None):
        r"""
        Read safe senders from YAML file and return as JSON object.
        The safe_senders YAML file contains a list of patterns that can be email addresses or domains.

        Args:
            rules_json: Not used, kept for backward compatibility

        Returns:
            list: List of safe sender patterns, or empty list if file not found/error
        """

        self.log_print("Importing safe senders from YAML file...")
        safe_senders = []
        result = {"safe_senders": []}

        try:
            if rules_file is None:
                rules_file = self.active_safe_senders_file
            if not os.path.exists(rules_file):
                self.log_print(f"Safe senders YAML file not found: {rules_file}")
                return result

            # Read YAML file and convert to Python JSON object per rules_safe_senders.proto definition
            # The YAML file should contain a list of safe senders or a dictionary with a "safe_senders" key
            # where safe_senders[safe_senders] is a list of strings that hold regex pattern strings
            # Honor the rules_file parameter rather than the constant
            with open(rules_file, 'r', encoding='utf-8') as yaml_file:
                safe_senders = yaml.safe_load(yaml_file)

            if not safe_senders:    # check if file was empty or did not load correctly
                self.log_print("No content found in YAML file")
                return result

            # Extract safe senders list from YAML structure per rules_safe_senders.proto definition
            if isinstance(safe_senders, dict) and 'safe_senders' in safe_senders:
                self.log_print(f"Successfully imported {len(safe_senders['safe_senders'])} safe senders from YAML file")
                self.log_print(f"Safe senders (first 5): {safe_senders['safe_senders'][:5]}")
                result = json.loads(json.dumps(safe_senders, default=str))
            elif isinstance(safe_senders, list):
                self.log_print(f"ERROR:  Safe_senders imported as a list from YAML file - need to resolve")
                result = {"safe_senders": safe_senders}
            else:
                self.log_print("No 'safe_senders' key found in YAML file")

            return result

        except Exception as e:
            self.log_print(f"Error importing safe senders from YAML: {str(e)}")
            self.log_print(f"Error details: {str(e.__class__.__name__)}")
            self.log_print(f"Traceback: {traceback.format_exc()}")
            return result

    def get_yaml_rules(self, rules_file=None):
        """Import rules from yaml file and return as JSON object (not string)"""
        #*** UPdate to use .proto file
        self.log_print("Importing rules from YAML file...")
        try:
            if rules_file is None:
                rules_file = self.active_rules_file
            if not os.path.exists(rules_file):
                self.log_print(f"Rules YAML file not found: {rules_file}")
                return []

            # Read YAML file and convert to Python object
            with open(rules_file, 'r', encoding='utf-8') as yaml_file:
                yaml_content = yaml.safe_load(yaml_file)

            if not yaml_content:
                self.log_print("No rules found in YAML file")
                return []

            # Handle new format with version and settings
            if isinstance(yaml_content, dict) and "rules" in yaml_content:
                # Extract the rules array from the new format
                rules = yaml_content["rules"]
                # Preserve other top-level elements like version and settings
                result = yaml_content
            else:
                # Handle old format where rules were at the top level
                rules = yaml_content if isinstance(yaml_content, list) else [yaml_content]
                result = {"rules": rules}

            self.log_print(f"Successfully imported {len(rules)} rules from YAML file")

            # Convert to JSON using json.dumps and json.loads to ensure consistent structure
            result_json = json.loads(json.dumps(result, default=str))

            # Optional diagnostics: show first few patterns per condition for quick visual scan
            try:
                preview_n = 3
                cond_keys = ["from", "subject", "body", "header"]
                head = {k: [] for k in cond_keys}
                for rule in result_json.get("rules", [])[:preview_n]:
                    conds = rule.get("conditions", {}) or {}
                    for ck in cond_keys:
                        vals = conds.get(ck)
                        if isinstance(vals, list):
                            head[ck].extend(vals[:preview_n])
                for ck in cond_keys:
                    if head[ck]:
                        self.log_print(f"Initial {ck} patterns (first {preview_n}): {head[ck][:preview_n]}", level="DEBUG")
            except Exception:
                pass

            return result_json

        except Exception as e:
            self.log_print(f"Error importing rules from YAML: {str(e)}")
            self.log_print(f"Error details: {str(e.__class__.__name__)}")
            import traceback
            self.log_print(f"Traceback: {traceback.format_exc()}")
            return []

    def export_safe_senders_to_yaml(self, rules_json=None, rules_file=None):
        """Export (updated) safe_senders JSON to yaml file"""
        # Update timestamp for each rule - may not be used
        timestamp_rule = datetime.now().isoformat()

        try:
            if rules_json is None:   #this should never happen
                self.log_print("safe_senders JSON is Empty, do not overwrite safe_senders yaml and exit with error")
                return None

            # Convert rules_json to dict if a string format
            if isinstance(rules_json, str):  # convert to JSON
                rules = json.loads(rules_json)
                self.log_print(f"export_safe_senders: Found safe_senders as string and converted to JSON object")
            elif isinstance(rules_json, dict):
                rules = json.loads(json.dumps(rules_json))
                self.log_print(f"export_safe_senders: Found rsafe_senders JSON is a dict and converted to JSON object")
            else:
                # Ensure consistent structure by using json conversion
                rules = json.loads(json.dumps(rules_json, default=str))
                self.log_print(f"export_safe_senders: Standardized rules JSON structure")

            standardized_rules = rules
            # set to all lowercase and remove whitespace
            standardized_rules["safe_senders"] = [item.lower().strip() for item in standardized_rules["safe_senders"]]
            # remove duplicates from the standardized_rules
            standardized_rules["safe_senders"] = list(dict.fromkeys(standardized_rules["safe_senders"]))
            # Sort the safe_senders list
            standardized_rules["safe_senders"] = sorted(standardized_rules["safe_senders"])

            self.log_print(f"Processing {len(standardized_rules["safe_senders"])} safe_senders rules")
            #self.log_print(f"Show list of standardized_rules safe_senders: {standardized_rules}")

            # 03/31/2025 Harold Kimmey Write json_rules to YAML file
            # Ensure directory exists
            if rules_file is None:
                rules_file = self.active_safe_senders_file
            rules_dir = os.path.dirname(rules_file)
            if rules_dir:  # Only create directory if path has a directory component
                os.makedirs(rules_dir, exist_ok=True)

            # The below section does the following:
            #   Ensure the JSON rules_json object is a valid JSON object before writing to YAML file
            #   Make a backup of the current yaml_file using format "yaml_backup_yyyymmdd_hhmmss.yaml"
            #   Write out the YAML file using YAML_RULES_FILE_temp.yaml
            #   do a get_yaml_rules() to read the file back in and compare it to the original rules_json object to ensure it is a valid match
            #       can use the compare_rules() function to do this
            #   If the comparison is successful, write out the JSON object to YAML_RULES_FILE (use code below)
            #       Convert JSON object to YAML and write to file
            #   If no errors writing the YAML_RULES_FILE, delete the temp file

            # Create a backup of the current YAML file if it exists in archive directory
            if os.path.exists(rules_file):
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                base_name = os.path.splitext(os.path.basename(rules_file))[0]
                backup_file = f"{YAML_ARCHIVE_PATH}{base_name}_backup_{timestamp}.yaml"
                try:
                    import shutil
                    # Ensure archive directory exists
                    os.makedirs(YAML_ARCHIVE_PATH, exist_ok=True)
                    shutil.copy2(rules_file, backup_file)
                    self.log_print(f"Created backup of existing safe_senders YAML file: {backup_file}")
                except Exception as e:
                    self.log_print(f"Warning: Could not create backup safe_senders file: {str(e)}")

            try:
                with open(rules_file, 'w', encoding='utf-8') as yaml_file:
                    # DEPRECATED 10/18/2025: Regex filename check removed - all files now use single quotes for regex stability
                    # Prefer single quotes when writing the regex safe_senders file to avoid escape churn
                    # default_style = "'" if os.path.basename(rules_file) == os.path.basename(YAML_RULES_SAFE_SENDERS_FILE_REGEX) else '"'
                    # Always use single quotes for regex pattern stability
                    default_style = "'"
                    yaml.dump(standardized_rules, yaml_file, sort_keys=False, default_flow_style=False, default_style=default_style)
                self.log_print(f"Successfully exported {len(standardized_rules['safe_senders'])} safe_senders to YAML file: {rules_file}")

                # # Clean up - delete temporary file
                # try:
                #     os.remove(temp_file)
                #     self.log_print(f"Deleted temporary safe_senders file: {temp_file}")
                # except Exception as e:
                #     self.log_print(f"Warning: Could not delete temporary safe_senders file: {str(e)}")

                return True

            except Exception as e:
                self.log_print(f"Error writing to temporary safe_senders file: {str(e)}")
                return False

        except Exception as e:
            self.log_print(f"Error exporting safe_senders: {str(e)}")
            self.log_print(f"Error details: {str(e.__class__.__name__)}")
            import traceback
            self.log_print(f"Traceback: {traceback.format_exc()}")
            return False


    def export_rules_to_yaml(self, rules_json=None, rules_file=None):
        """Export JSON/YAML rules to yaml file"""
        # Update timestamp for each rule
        timestamp = datetime.now().isoformat()

        try:
            if rules_json is None:   #this should never happen
                self.log_print("Rules JSON is Empty, do not overwrite rules_file yaml and exit with error")
                return None

            # Convert rules_json to JSON object if it's a string or dict
            if isinstance(rules_json, str):
                rules = json.loads(rules_json)
                self.log_print(f"export_rules: Found rules_json is a string and converted to JSON object")
            elif isinstance(rules_json, dict):
                rules = json.loads(json.dumps(rules_json))
                self.log_print(f"export_rules: Found rules_json is a dict and converted to JSON object")
            else:
                # Ensure consistent structure by using json conversion
                rules = json.loads(json.dumps(rules_json, default=str))
                self.log_print(f"export_rules: Standardized rules JSON structure")

            # Handle both old format (rules array) and new format (full YAML structure)
            if isinstance(rules, list):
                # Old format: rules is a list
                rules_list = rules
                full_structure = {"rules": rules_list}
                self.log_print(f"export_rules: Processing old format (rules array)")
            elif isinstance(rules, dict) and "rules" in rules:
                # New format: rules is a dict with "rules" key
                rules_list = rules["rules"]
                full_structure = rules
                self.log_print(f"export_rules: Processing new format (full YAML structure)")
            else:
                self.log_print(f"export_rules: Invalid rules format - expected list or dict with 'rules' key")
                return False

            for rule in rules_list:
                if isinstance(rule, dict):
                    # Update last_modified in metadata if present, else create metadata
                    if "metadata" in rule and isinstance(rule["metadata"], dict):
                        rule["metadata"]["last_modified"] = timestamp
                    else:
                        rule["metadata"] = {"last_modified": timestamp} #*** need to change so that this happens when rules change

            # Ensure all string values are properly formatted for YAML export
            def ensure_string_values(obj):
                if isinstance(obj, dict):
                    return {k: ensure_string_values(v) for k, v in obj.items()}
                elif isinstance(obj, list):
                    return [ensure_string_values(item) for item in obj]
                elif obj is None:
                    return ""  # Convert None to empty string
                else:
                    return str(obj)  # Ensure all values are strings

            # Apply string formatting to all rules

            standardized_rules = full_structure
            standardized_rules["rules"] = ensure_string_values(standardized_rules["rules"])
            # Sort all the condition_types for ease in finding them visually
            for rule in standardized_rules.get("rules", []):
                if "conditions" in rule:
                    for condition_type in ["header", "body", "from", "subject"]:
                        if condition_type in rule["conditions"] and isinstance(rule["conditions"][condition_type], list):
                            # ensure all values in rule["conditions"][condition_type] are lowercase and strip whitespace
                            rule["conditions"][condition_type] = [item.lower().strip() for item in rule["conditions"][condition_type]]
                            rule["conditions"][condition_type] = [ensure_string_values(item) for item in rule["conditions"][condition_type]]
                            # remove duplicates from the condition_type list
                            rule["conditions"][condition_type] = list(dict.fromkeys(rule["conditions"][condition_type]))
                            # Sort the condition_type list
                            rule["conditions"][condition_type] = sorted(rule["conditions"][condition_type])


        #    # remove duplicates from the standardized_rules
        #     standardized_rules["safe_senders"] = list(dict.fromkeys(standardized_rules["safe_senders"]))
        #     # Sort the safe_senders list
        #     standardized_rules["safe_senders"] = sorted(standardized_rules["safe_senders"])

            formatted_output = standardized_rules
            self.log_print(f"Number of rules: {len(rules_list)}")
            # self.log_print(f"Show list of rules: {rules_list}")
            self.log_print(f"Number of standardized rules: {len(standardized_rules["rules"])}")
            #self.log_print(f"Show list of standardized_rules: {standardized_rules["rules"]}")
            self.log_print(f"Number of formatted_output: {len(formatted_output["rules"])}")
            #self.log_print(f"Show list of formatted_output: {formatted_output["rules"]}")

            # 03/31/2025 Harold Kimmey Write json_rules to YAML file
            # Ensure directory exists
            if rules_file is None:
                rules_file = self.active_rules_file
            rules_dir = os.path.dirname(rules_file)
            if rules_dir:  # Only create directory if path has a directory component
                os.makedirs(rules_dir, exist_ok=True)

            # The below section does the following:
            #   Ensure the JSON rules_json object is a valid JSON object before writing to YAML file
            #   Make a backup of the current yaml_file using format "yaml_backup_yyyymmdd_hhmmss.yaml"
            #   Write out the YAML file using YAML_RULES_FILE_temp.yaml
            #   do a get_yaml_rules() to read the file back in and compare it to the original rules_json object to ensure it is a valid match
            #       can use the compare_rules() function to do this
            #   If the comparison is successful, write out the JSON object to YAML_RULES_FILE (use code below)
            #       Convert JSON object to YAML and write to file
            #   If no errors writing the YAML_RULES_FILE, delete the temp file

            # Create a backup of the current YAML file if it exists
            if rules_file is None:
                rules_file = self.active_rules_file
            if os.path.exists(rules_file):
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                base_name = os.path.splitext(os.path.basename(rules_file))[0]
                backup_file = f"{YAML_ARCHIVE_PATH}{base_name}_backup_{timestamp}.yaml"
                try:
                    import shutil
                    # Ensure archive directory exists
                    os.makedirs(YAML_ARCHIVE_PATH, exist_ok=True)
                    shutil.copy2(rules_file, backup_file)
                    self.log_print(f"Created backup of existing YAML file: {backup_file}")
                except Exception as e:
                    self.log_print(f"Warning: Could not create backup file: {str(e)}")

            # Write to file
            try:

                with open(rules_file, 'w', encoding='utf-8') as yaml_file:
                    # Always use single quotes for regex pattern stability
                    default_style = "'"
                    yaml.dump(formatted_output, yaml_file, sort_keys=False, default_flow_style=False, default_style=default_style, width=4096)
                    self.log_print(f"Successfully exported {len(standardized_rules['rules'])} rules to YAML file: {rules_file}")

                return True

            except Exception as e:
                self.log_print(f"Error writing to temporary file: {str(e)}")
                return False

        except Exception as e:
            self.log_print(f"Error exporting rules: {str(e)}")
            self.log_print(f"Error details: {str(e.__class__.__name__)}")
            import traceback
            self.log_print(f"Traceback: {traceback.format_exc()}")
            return False


    def get_rules(self, use_regex_files: bool = False):

        """Get rules from YAML file if available, otherwise from Outlook"""

        # Note: actual file chosen will be self.active_rules_file set by main()
        YAML_rules = self.get_yaml_rules()
        self.log_print(f"Import rules from YAML ({self.active_rules_file})")

        safe_senders = self.get_safe_senders_rules()

        self.log_print(f"Number of rules: {len(YAML_rules['rules'])}")
        # self.log_print(f"Show list of rules: {YAML_rules['rules']}")
        self.log_print(f"Number of safe_senders rules: {len(safe_senders['safe_senders'])}")
        # self.log_print(f"Show list of safe_senders rules: {safe_senders['safe_senders']}")

        # Otherwise, return the rules directly
        return YAML_rules, safe_senders

    def print_rules_summary(self, rules):   # rules should be a JSON object
        """Print a summary of all rules in the yaml file"""
        try:
            # add a check to convert to a JSON object (if it a string or dict)
            if isinstance(rules, str) or isinstance(rules, dict):
                rules = json.loads(json.dumps(rules))

            self.log_print(f"{CRLF}Rules Summary:")
            for rule in rules:
                self.log_print(f"\nRule: {rule['name']} (Enabled: {rule['enabled']})")
                for cond_type, values in rule['conditions'].items():
                    if not isinstance(values, list):
                        values = [values]
                    self.log_print(f"  {cond_type} conditions:")
                    for value in values:
                        self.log_print(f"    - {value}")
                self.log_print(f"  Actions:")
                for action, value in rule['actions'].items():
                    self.log_print(f"    - {action}: {value}")

        except Exception as e:
            self.log_print(f"Error printing rules summary: {str(e)}")

    def combine_email_header_lines(self, email_header):
        r"""
        Combine email headers, handling lines split across multiple lines, and find the first line containing "from:".

        Args:
            email_headers (str): The email headers as a single string.

        Returns:
            str: The first line containing "from:", or None if not found.
        """
        # Build email_header, combining lines split across multiple lines into one line (combine From:)
        email_header_list = []
        for line in email_header.splitlines():
            if line.startswith((' ', '\t')):
                # Continuation line, append to the previous line
                email_header_list[-1] += ' ' + line.strip()
            else:
                # New header field
                email_header_list.append(line.strip())

        # Convert email_header_list back into a single string
        updated_email_header = '\n'.join(email_header_list)

        # Sanitize the updated email header
        updated_email_header = self._sanitize_string(updated_email_header)

        # Convert to lowercase for easier keyword matching
        updated_email_header = updated_email_header.lower()

        return updated_email_header

    def header_from(self, email_header):
        r"""
        Process email headers to find the first line containing "from:" and extract the domain.

        Args:
            email_header (str): The email headers as a single string.

        Returns:
            str: The domain extracted from the "from:" line, padded to 20 characters, or None if not found.
        """
        line_with_from = ""  # Initialize with an empty string
        blank = ""

        # Handle case where email_header could be a list
        if isinstance(email_header, list):
            email_header = "\n".join(email_header)

        # Iterate over each element in email_header
        for line in email_header.splitlines():
            if line.lower().startswith("from:"):
                line_with_from = line
                break  # find the first line that starts with "from:" then exit loop

        #   print(f"line_with_from: {line_with_from}")  # Debugging output

        if line_with_from:
            from_domain = re.search(r'@[\w.-]+', line_with_from)
            if from_domain:
                from_domain_str = from_domain.group(0)
                #   print(f"from_domain_str: {from_domain_str}")  # Debugging output
                return from_domain_str

        return blank

    def from_report(self, emails_to_process, emails_added_info, rules_json):
        r"""
        Generate a report of emails with phishing indicators or no rule matches, including the From domain.

        Args:
            emails_to_process (list): List of emails to process.
            emails_added_info (list): List of dictionaries containing additional information about each email.
        """

        processed_count = 0

        # Print a list for Phishing OR Match=false with From: "@<domain>.<>" so they can be easily added to the rules

        for email in emails_to_process:
            processed_count += 1
            email_index = emails_to_process.index(email)
            try:
                if ("phishing_indicators" in emails_added_info[email_index] and
                    emails_added_info[email_index]["phishing_indicators"] is not None):
                    # Create a string from email.header for the From: line with format: "@<domain>.<> (20 characters or less,
                    # padded to 20) Email <n> (with 2 leading blanks)"

                    email_header = emails_added_info[email_index]["email_header"]
                    from_domain = self.header_from(email_header)

                    output_string = (from_domain.ljust(20) +
                                    f"| Email {email_index+1:>3} | " +
                                    f"Phishing indicators: {emails_added_info[email_index]['phishing_indicators']}")
                    self.log_print(f"{output_string}", level="INFO")
                    simple_print(f"{output_string}")
            except Exception as e:
                simple_print(f"Error processing phishing indicators for email: {str(e)}")

            try:
                if (emails_added_info[email_index]["match"] == False):
                    # Create a string from email.header for the From: line with format: "@<domain>.<> (20 characters or less,
                    # padded to 20) Email <n> (with 2 leading blanks)"

                    email_header = emails_added_info[email_index]["email_header"]
                    from_domain = self.header_from(email_header)

                    output_string = from_domain.ljust(20) + f"| Email {email_index+1:>3} | Matched no rules"
                    self.log_print(f"{output_string}", level="INFO")
                    simple_print(f"{output_string}")

            except Exception as e:
                self.log_print(f"Error processing match = false email: {str(e)}")

            if (DEBUG) and (processed_count >= DEBUG_EMAILS_TO_PROCESS):
                break  # Stop processing more emails in debug mode, then write the report and prompt for rule updates


    def get_unique_URL_stubs(self, email_body):
        r"""
        Extract unique URL stubs from the email body in the formats "/<domain>.<>"
        Args:
            email_body (str): The body of the email.
        """

        unique_stubs = []
        seen_stubs = set()
        url_pattern = re.compile(r'(\.[\w-]+\.[\w-]+)|(/[\w-]+\.[\w-]+)')
        for line in email_body.splitlines():
            matches = url_pattern.findall(line)
            for match in matches:
                stub = match[0] if match[0] else match[1]
                # Remove leading "/" or "."
                cleaned_stub = stub.lstrip('/.')
                # Add both versions to the list if not seen before
                if '/' + cleaned_stub not in seen_stubs:
                    unique_stubs.append('/' + cleaned_stub)
                    seen_stubs.add('/' + cleaned_stub)
                if '.' + cleaned_stub not in seen_stubs:
                    unique_stubs.append('.' + cleaned_stub)
                    seen_stubs.add('.' + cleaned_stub)
        return unique_stubs

    def URL_report(self, emails_to_process, emails_added_info):
        r"""
        Generate a report of emails with phishing indicators or no rule matches,
            including unique URL stubs "/<domain>.<>" and ".<domain>.<>" from the body.

        Args:
            emails_to_process (list): List of emails to process.
            emails_added_info (list): List of dictionaries containing additional information about each email.
        """

        processed_count = 0

        # Print a list for Phishing OR Match=false, report body unique URL stubs "/<domain>.<>" and ".<domain>.<>" so they can be easily added to the rules
        #     collect them all first, then determine uniqueness, then print one per line

        for email in emails_to_process:
            processed_count += 1
            email_index = emails_to_process.index(email)
            try:
                if ("phishing_indicators" in emails_added_info[email_index] and
                    emails_added_info[email_index]["phishing_indicators"] is not None):
                    # Create a string from email.header for the From: line with format: "@<domain>.<> (20 characters or less,
                    # padded to 20) Email <n> (with 2 leading blanks)"

                    unique_URL_stubs = self.get_unique_URL_stubs(email.Body)

                    for stub in unique_URL_stubs:
                        output_string = (stub.ljust(30) +
                                    f"| Email {email_index+1:>3} | " +
                                    f"From: {self._sanitize_string(email.SenderEmailAddress)}")
                        self.log_print(f"{output_string}",level="INFO")
                        simple_print(f"{output_string}")
            except Exception as e:
                self.log_print(f"Error processing phishing indicators for email: {str(e)}")


            if (DEBUG) and (processed_count >= DEBUG_EMAILS_TO_PROCESS):
                break  # Stop processing more emails in debug mode, then write the report and prompt for rule updates

    def _process_conditions(self, conditions_obj, is_exception):
        """Helper method to process rule conditions or exceptions"""
        conditions = {}

        try:
            # From addresses
            if hasattr(conditions_obj, "From") and conditions_obj.From:
                try:
                    conditions["from"] = [
                        {
                            "address": recipient.Address if hasattr(recipient, "Address") else None,
                            "name": recipient.Name if hasattr(recipient, "Name") else None
                        }
                        for recipient in conditions_obj.From.Recipients
                    ]
                    # Print the contents of conditions["from"] #can be used for extra debugging information
                    if is_exception:
                        self.log_print(f"Exception conditions['from']: {conditions['from']}", "DEBUG")
                    else:
                        self.log_print(f"Conditions['from']: {conditions['from']}", "DEBUG")

                except Exception as e:
                    self.log_print(f"Error processing From condition: {str(e)}")
                    conditions["from"] = []

            # Subject keywords
            if hasattr(conditions_obj, "Subject") and conditions_obj.Subject:
                try:
                    if is_exception:
                        self.log_print(f"Exception conditions_obj.Subject.Text: {conditions_obj.Subject.Text}", "DEBUG")
                    else:
                        self.log_print(f"Conditions_obj.Subject.Text: {conditions_obj.Subject.Text}", "DEBUG")

                    if hasattr(conditions_obj.Subject, "Text"):
                        if isinstance(conditions_obj.Subject.Text, str):
                            subject_text = conditions_obj.Subject.Text
                        elif isinstance(conditions_obj.Subject.Text, tuple):
                            subject_text = "; ".join(conditions_obj.Subject.Text)
                        else:
                            subject_text = ""
                    else:
                        subject_text = ""
                    conditions["subject"] = [kw.strip() for kw in subject_text.split(";") if kw.strip()]
                except Exception as e:
                    self.log_print(f"Error processing Subject condition: {str(e)}")
                    conditions["subject"] = []

            # Body keywords
            if hasattr(conditions_obj, "Body") and conditions_obj.Body:
                try:
                    if is_exception:
                        self.log_print(f"Exception conditions_obj.Body.Text: {conditions_obj.Body.Text}", "DEBUG")
                    else:
                        self.log_print(f"Conditions_obj.Body.Text: {conditions_obj.Body.Text}", "DEBUG")

                    if hasattr(conditions_obj.Body, "Text"):
                        if isinstance(conditions_obj.Body.Text, str):
                            body_text = conditions_obj.Body.Text
                        elif isinstance(conditions_obj.Body.Text, tuple):
                            body_text = "; ".join(conditions_obj.Body.Text)
                            # self.log_print(f"body_text: {body_text}")
                        else:
                            body_text = ""
                    else:
                        body_text = ""
                    conditions["body"] = [kw.strip() for kw in body_text.split(";") if kw.strip()]
                except Exception as e:
                    self.log_print(f"Error processing Body condition: {str(e)}")
                    conditions["body"] = []

            # Header keywords
            if hasattr(conditions_obj, "MessageHeader") and conditions_obj.MessageHeader:
                try:
                    if is_exception:
                        self.log_print(f"Exception conditions_obj.MessageHeader.Text: {conditions_obj.MessageHeader.Text}", "DEBUG")
                    else:
                        self.log_print(f"Conditions_obj.MessageHeader.Text: {conditions_obj.MessageHeader.Text}", "DEBUG")

                    if hasattr(conditions_obj.MessageHeader, "Text"):
                        if isinstance(conditions_obj.MessageHeader.Text, str):
                            header_text = conditions_obj.MessageHeader.Text
                        elif isinstance(conditions_obj.MessageHeader.Text, tuple):
                            header_text = "; ".join(conditions_obj.MessageHeader.Text)
                        else:
                            header_text = ""
                    else:
                        header_text = ""
                    conditions["header"] = [kw.strip() for kw in header_text.split(";") if kw.strip()]
                except Exception as e:
                    self.log_print(f"Error processing Header condition: {str(e)}")
                    conditions["header"] = []

            # Attachment condition
            if hasattr(conditions_obj, "Attachment"):
                if is_exception:
                    self.log_print(f"Exception conditions_obj.Attachment: {bool(conditions_obj.Attachment)}", "DEBUG")
                else:
                    self.log_print(f"Conditions_obj.Attachment: {bool(conditions_obj.Attachment)}", "DEBUG")

                conditions["has_attachments"] = bool(conditions_obj.Attachment)

        except Exception as e:
            self.log_print(f"Error processing conditions: {str(e)}")
            conditions["error"] = str(e)

        return conditions

    def _process_actions(self, actions_obj):
        """Helper method to process rule actions"""
        actions = {}

        try:
            # Move to Folder
            if hasattr(actions_obj, "MoveToFolder") and actions_obj.MoveToFolder:
                try:
                    actions["move_to_folder"] = {
                        "folder_path": actions_obj.MoveToFolder.FolderPath if hasattr(actions_obj.MoveToFolder, "FolderPath") else None,
                        "folder_name": actions_obj.MoveToFolder.Name if hasattr(actions_obj.MoveToFolder, "Name") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing MoveToFolder action: {str(e)}")

            # Copy to Folder
            if hasattr(actions_obj, "CopyToFolder") and actions_obj.CopyToFolder:
                try:
                    actions["copy_to_folder"] = {
                        "folder_path": actions_obj.CopyToFolder.FolderPath if hasattr(actions_obj.CopyToFolder, "FolderPath") else None,
                        "folder_name": actions_obj.CopyToFolder.Name if hasattr(actions_obj.CopyToFolder, "Name") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing CopyToFolder action: {str(e)}")

            # Assign to Category
            if hasattr(actions_obj, "AssignToCategory") and actions_obj.AssignToCategory:
                try:
                    # Outlook may store one or more category names in a collection property.
                    # First, check if there is a Categories collection
                    if hasattr(actions_obj.AssignToCategory, "Categories") and actions_obj.AssignToCategory.Categories:
                        # Convert the collection into a list
                        category_collection = actions_obj.AssignToCategory.Categories
                        # Depending on the COM object, you might iterate over it
                        category_names = [cat for cat in category_collection]
                        # Join the names if more than one
                        category_name = ", ".join(category_names)
                    else:
                        # Fall back to a simple property "Category" if available.
                        category_name = getattr(actions_obj.AssignToCategory, "Category", None)
                    self.log_print(f"AssignToCategory action found, category_name: {category_name}")
                    actions["assign_to_category"] = {
                        "category_name": category_name
                    }
                except Exception as e:
                    self.log_print(f"Error processing AssignToCategory action: {str(e)}")
                    actions["assign_to_category"] = {
                        "category_name": None
                    }

            # Delete
            if hasattr(actions_obj, "Delete") and actions_obj.Delete:
                actions["delete"] = True

            # Stop processing more rules
            if hasattr(actions_obj, "StopProcessingMoreRules") and actions_obj.StopProcessingMoreRules:
                try:
                    self.log_print("StopProcessingMoreRules action found")
                    actions["stop_processing_more_rules"] = True
                except Exception as e:
                    self.log_print(f"Error processing StopProcessingMoreRules action: {str(e)}")

            # Mark as Read
            if hasattr(actions_obj, "MarkAsRead") and actions_obj.MarkAsRead:
                try:
                    self.log_print("MarkAsRead action found")
                    actions["mark_as_read"] = True
                except Exception as e:
                    self.log_print(f"Error processing MarkAsRead action: {str(e)}")

            # Clear the Message Flag
            if hasattr(actions_obj, "ClearFlag") and actions_obj.ClearFlag:
                try:
                    self.log_print("ClearFlag action found")
                    actions["clear_flag"] = True
                except Exception as e:
                    self.log_print(f"Error processing ClearFlag action: {str(e)}")

            # Forward
            if hasattr(actions_obj, "Forward") and actions_obj.Forward:
                try:
                    actions["forward"] = [
                        {
                            "address": recipient.Address if hasattr(recipient, "Address") else None,
                            "name": recipient.Name if hasattr(recipient, "Name") else None
                        }
                        for recipient in actions_obj.Forward.Recipients
                    ]
                except Exception as e:
                    self.log_print(f"Error processing Forward action: {str(e)}")
                    actions["forward"] = []

            # Redirect
            if hasattr(actions_obj, "Redirect") and actions_obj.Redirect:
                try:
                    actions["redirect"] = [
                        {
                            "address": recipient.Address if hasattr(recipient, "Address") else None,
                            "name": recipient.Name if hasattr(recipient, "Name") else None
                        }
                        for recipient in actions_obj.Redirect.Recipients
                    ]
                except Exception as e:
                    self.log_print(f"Error processing Redirect action: {str(e)}")
                    actions["redirect"] = []

            # Reply
            if hasattr(actions_obj, "Reply") and actions_obj.Reply:
                try:
                    actions["reply"] = {
                        "template": actions_obj.Reply.Template if hasattr(actions_obj.Reply, "Template") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing Reply action: {str(e)}")

            # Play Sound
            if hasattr(actions_obj, "PlaySound") and actions_obj.PlaySound:
                try:
                    actions["play_sound"] = {
                        "sound_file": actions_obj.PlaySound.SoundFile if hasattr(actions_obj.PlaySound, "SoundFile") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing PlaySound action: {str(e)}")

            # Display Desktop Alert
            if hasattr(actions_obj, "DisplayDesktopAlert") and actions_obj.DisplayDesktopAlert:
                actions["display_desktop_alert"] = True

            # Set Importance
            if hasattr(actions_obj, "SetImportance") and actions_obj.SetImportance:
                try:
                    actions["set_importance"] = {
                        "importance_level": actions_obj.SetImportance.ImportanceLevel if hasattr(actions_obj.SetImportance, "ImportanceLevel") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing SetImportance action: {str(e)}")

            # Set Sensitivity
            if hasattr(actions_obj, "SetSensitivity") and actions_obj.SetSensitivity:
                try:
                    actions["set_sensitivity"] = {
                        "sensitivity_level": actions_obj.SetSensitivity.SensitivityLevel if hasattr(actions_obj.SetSensitivity, "SensitivityLevel") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing SetSensitivity action: {str(e)}")

            # Print
            if hasattr(actions_obj, "Print") and actions_obj.Print:
                actions["print"] = True

            # Run Script
            if hasattr(actions_obj, "RunScript") and actions_obj.RunScript:
                try:
                    actions["run_script"] = {
                        "script_path": actions_obj.RunScript.ScriptPath if hasattr(actions_obj.RunScript, "ScriptPath") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing RunScript action: {str(e)}")

            # Start Application
            if hasattr(actions_obj, "StartApplication") and actions_obj.StartApplication:
                try:
                    actions["start_application"] = {
                        "application_path": actions_obj.StartApplication.ApplicationPath if hasattr(actions_obj.StartApplication, "ApplicationPath") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing StartApplication action: {str(e)}")

            # Mark as Task
            if hasattr(actions_obj, "MarkAsTask") and actions_obj.MarkAsTask:
                try:
                    actions["mark_as_task"] = {
                        "task_due_date": actions_obj.MarkAsTask.TaskDueDate if hasattr(actions_obj.MarkAsTask, "TaskDueDate") else None
                    }
                except Exception as e:
                    self.log_print(f"Error processing MarkAsTask action: {str(e)}")

        except Exception as e:
            self.log_print(f"Error processing actions: {str(e)}")

        return actions

    def get_safe_input(self, prompt_text, valid_responses=None, isregex=False, help_text=None):
        r"""
        Get user input with security validation.

        Args:
            prompt_text (str): The text to display to the user
            valid_responses (list, optional): List of valid responses. If None, any non-empty input is valid.
            isregex (bool, optional): Whether to allow regex patterns in the input. Defaults to False.

        Returns:
            str: The validated user input
        """
        while True:
            # Get user input
            user_input = input(prompt_text).strip().lower()

            # Provide contextual help when '?' is entered; then re-prompt
            if user_input == '?':
                if help_text:
                    print(help_text)
                else:
                    print("Options: d=add domain regex to header rule, e=add email to header rule, s=add to safe_senders (literal), sd=add sender-domain regex to safe_senders, ?=help")
                continue

            # Define dangerous patterns based on whether regex is allowed
            if isregex:
                # For regex input, we need to be more permissive but still prevent command injection
                dangerous_patterns = [
                    ';', '--', '/*', '*/', 'union', 'select', 'insert', 'update', 'delete',
                    'drop', 'exec', 'execute', '<script', 'javascript:', 'onerror', 'onload',
                    '$(', '${', '`', '&&', '||', '|'  # Allow < and > for regex character classes
                ]

                # Check if the regex pattern is valid by trying to compile it
                try:
                    import re
                    re.compile(user_input)
                except re.error:
                    print("Invalid regex pattern. Please try again.")
                    continue

            else: #*** if not regex, check for valid responses
                # Standard dangerous patterns for non-regex input
                dangerous_patterns = [
                    ';', '--', '/*', '*/', 'union', 'select', 'insert', 'update', 'delete',
                    'drop', 'exec', 'execute', '<script', 'javascript:', 'onerror', 'onload',
                    '$(', '${', '`', '&&', '||', '|', '>', '<', '&lt;', '&gt;'
                ]

                has_dangerous_pattern = any(pattern in user_input.lower() for pattern in dangerous_patterns)

                if has_dangerous_pattern:
                    print("Invalid input. Please try again.")
                    continue

                # Check if response is valid (only for non-regex input)
                if valid_responses and not isregex and user_input not in valid_responses:
                    print(f"Please enter one of: {', '.join(valid_responses)}")
                    continue

            # For regex mode and valid_responses, we could check if the pattern matches any of the valid responses
            # but typically regex mode would be used without valid_responses constraints

            return user_input


    def prompt_update_rules(self, emails_to_process, emails_added_info, rules_json, safe_senders):
        r"""
        Prompt user to update rules based on unfiltered emails.

        Args:
            emails_to_process (list): List of emails processed.
            emails_added_info (list): Additional info about processed emails.
            rules_json (list): Current rules in JSON format that may be updated.

        Returns:
            list: Updated rules in JSON format.
        """
        self.log_print(f"{CRLF}Checking for emails that can be added to rules...")
        # Surface current mode and file paths for clarity during interactive updates
        self.log_print(f"Interactive updates will write to: rules={self.active_rules_file}, safe_senders={self.active_safe_senders_file}")
        unfiltered_emails = []

        self.log_print(f"Number of emails to process: {len(emails_to_process)}")

        # Find unfiltered emails (those with match=False)
        for i, email_info in enumerate(emails_added_info):
            if email_info["processed"] and email_info["match"] == False and i < len(emails_to_process):
                unfiltered_emails.append((emails_to_process[i], email_info))

        if not unfiltered_emails:
            self.log_print("No unfiltered emails found to update rules.")
            return rules_json, safe_senders
        else:
            self.log_print(f"Found {len(unfiltered_emails)} unfiltered emails to process for rule updates.")

        self.log_print(f"Found {len(unfiltered_emails)} unfiltered emails. Processing for possible rule updates...")
        simple_print(f"\nBeginning interactive rule update for {len(unfiltered_emails)} unfiltered emails")

        # Process each unfiltered email
        # NOTE:  assumes user will only want to update 1 rule per email
        count = 0

        for email, email_info in unfiltered_emails:
            try:
                rule_updated = False
                count += 1
                #   self.log_print(f"before assigning email_header")
                email_header = email_info["email_header"]
                #   self.log_print(f"for loop email_header: {email_header}")  # Debugging output
                subject = self._sanitize_string(email.Subject)
                self.log_print(f"Subject: {subject}")
                from_email = self._sanitize_string(email.SenderEmailAddress).lower()
                self.log_print(f"From: {from_email}")
                from_domain = self.header_from(email_header)
                self.log_print(f"Domain: {from_domain}")
                unique_urls = self.get_unique_URL_stubs(email.Body) # Extract URLs
                self.log_print(f"Unique URLs: {unique_urls}")

                # Check if the email matches any safe_senders patterns (using regex matching for newly added patterns)
                # Compile safe_senders patterns before checking to include any newly added patterns
                compiled_safe_senders = self._compile_pattern_list(safe_senders.get("safe_senders", []))
                matched_safe, matched_safe_pat = self._regex_match_header_any(compiled_safe_senders, email_header, from_email)
                if matched_safe:
                    self.log_print(f"Skipping email from safe sender (matched pattern: {matched_safe_pat}): {from_email}")
                    simple_print(f"Skipping email from safe sender (matched pattern: {matched_safe_pat}): {from_email}")
                    continue

                # Check if the email matches any header rules (using regex matching for newly added patterns)
                # Compile header patterns from all rules before checking to include any newly added patterns
                skip_email = False
                for rule in rules_json["rules"]:
                    header_patterns = rule.get("conditions", {}).get("header", [])
                    if header_patterns:
                        compiled_headers = self._compile_pattern_list(header_patterns)
                        matched_header, matched_header_pat = self._regex_match_header_any(compiled_headers, email_header, from_email)
                        if matched_header:
                            self.log_print(f"Skipping email as it matches rule '{rule['name']}' (matched pattern: {matched_header_pat})")
                            simple_print(f"Skipping email as it matches rule '{rule['name']}' (matched pattern: {matched_header_pat})")
                            skip_email = True
                            break
                if skip_email:
                    continue

                # Display email details
                print(f"{CRLF}" + "=" * 60)
                print(f"Subject: {subject}")
                print(f"From: {from_email}")
                print(f"Domain: {from_domain}")
                print(f"Unique URLs: {unique_urls}")

                response = ""

                # Step 1: Suggest header rule
                #*** for the following domains that host individual email addresses, only suggest adding full email address to header rules:
                #   gmail.com, yahoo.com, hotmail.com, outlook.com, aol.com, protonmail.com,
                domains_with_individual_emails = from_domain in [
                    "@gmail.com", "@yahoo.com", "@hotmail.com", "@outlook.com", "@aol.com", "@protonmail.com",
                ]


                if from_domain:
                    if domains_with_individual_emails:
                        # For individual email domains, suggest adding full email address
                        expected_responses = ['d', 'e', 's', 'sd', '?']   # Treat 'd' and 'e' as 'e' for adding to header rule; 'sd' adds sender domain regex to safe_senders
                        prompt = f"{CRLF}Add '{from_email}' to SpamAutoDeleteHeader rule or safe_senders? ({'/'.join(expected_responses)}): "
                        help_text = (
                            "Options:\n"
                            "  d  - Add sender domain regex to SpamAutoDeleteHeader (blocks by domain)\n"
                            "  e  - Add full sender email to SpamAutoDeleteHeader (blocks this email)\n"
                            "  s  - Add literal address/domain to safe_senders (never block)\n"
                            "  sd - Add sender-domain regex to safe_senders (never block any subdomain)\n"
                            "  ?  - Show this help"
                        )
                        response = self.get_safe_input(prompt, expected_responses, help_text=help_text)
                        if response in ['e', 'd']:  # Treat 'd' and 'e' as 'e' for adding to header rule
                            # Add from_email to safe_senders list
                            for rule in rules_json["rules"]:
                                if rule["name"] == "SpamAutoDeleteHeader":
                                    if "header" not in rule["conditions"]:
                                        rule["conditions"]["header"] = []
                                    rule["conditions"]["header"].append(from_email)
                                    rule_updated = True
                                    self.log_print(f"Added '{from_email}' to SpamAutoDeleteHeader rule")
                                    simple_print(f"Added '{from_email}' to SpamAutoDeleteHeader rule")
                                    try:
                                        # Persist immediately to the active file
                                        self.export_rules_to_yaml(rules_json)
                                        self.log_print(f"Appended to: {self.active_rules_file}")
                                    except Exception:
                                        pass
                        elif response == 's':
                            # Add from_domain to safe_senders list
                            safe_senders["safe_senders"].append(from_email)  # working HK 05/18/25
                            self.log_print(f"Added '{from_email}' to safe_senders list")
                            simple_print(f"Added '{from_email}' to safe_senders list")
                            rule_updated = True
                            try:
                                self.export_safe_senders_to_yaml(safe_senders)
                                self.log_print(f"Appended to: {self.active_safe_senders_file}")
                            except Exception:
                                pass
                        elif response == 'sd':
                            # Add sender's domain as a regex to safe_senders (any local part, any subdomains)
                            domain_regex = self.build_sender_domain_safe_regex(from_domain or from_email)
                            if domain_regex:
                                if domain_regex not in safe_senders.get("safe_senders", []):
                                    safe_senders["safe_senders"].append(domain_regex)
                                self.log_print(f"Added sender-domain regex '{domain_regex}' to safe_senders list")
                                simple_print(f"Added sender-domain regex to safe_senders: {domain_regex}")
                                rule_updated = True
                                try:
                                    self.export_safe_senders_to_yaml(safe_senders)
                                    self.log_print(f"Appended to: {self.active_safe_senders_file}")
                                except Exception:
                                    pass
                    else:
                        expected_responses = ['d', 'e', 's', 'sd', '?']   # 'sd' adds sender domain regex to safe_senders
                        prompt = f"{CRLF}Add '{from_email}' to SpamAutoDeleteHeader rule or safe_senders? ({'/'.join(expected_responses)}): "
                        help_text = (
                            "Options:\n"
                            "  d  - Add sender domain regex to SpamAutoDeleteHeader (blocks by domain)\n"
                            "  e  - Add full sender email to SpamAutoDeleteHeader (blocks this email)\n"
                            "  s  - Add literal address/domain to safe_senders (never block)\n"
                            "  sd - Add sender-domain regex to safe_senders (never block any subdomain)\n"
                            "  ?  - Show this help"
                        )
                        response = self.get_safe_input(prompt, expected_responses, help_text=help_text)
                        if response == 'd':
                            # Find the SpamAutoDeleteHeader rule in the rules list and append to its header conditions
                            # On 'd', add a domain-based regex anchored on the first meaningful subdomain below the TLD
                            for rule in rules_json["rules"]:
                                if rule["name"] == "SpamAutoDeleteHeader":
                                    if "header" not in rule["conditions"]:
                                        rule["conditions"]["header"] = []

                                    try:
                                        domain_regex = self.build_domain_regex_from_address(from_domain or from_email)
                                    except Exception:
                                        # Conservative default if unexpected input
                                        domain_regex = '@(?:[a-z0-9-]+\\.)*[a-z0-9-]+\\.[a-z0-9.-]+$'

                                    # Avoid duplicates
                                    if domain_regex not in rule["conditions"]["header"]:
                                        rule["conditions"]["header"].append(domain_regex)
                                        rule_updated = True
                                        self.log_print(f"Added domain regex '{domain_regex}' to SpamAutoDeleteHeader rule")
                                        simple_print(f"Added domain regex '{domain_regex}' to SpamAutoDeleteHeader rule")
                                        try:
                                            self.export_rules_to_yaml(rules_json)
                                            self.log_print(f"Appended to: {self.active_rules_file}")
                                        except Exception:
                                            pass

                        elif response == 's':
                            # Add from_domain to safe_senders list
                            safe_senders["safe_senders"].append(from_domain)  # working HK 05/18/25
                            self.log_print(f"Added '{from_domain}' to safe_senders list")
                            simple_print(f"Added '{from_domain}' to safe_senders list")
                            rule_updated = True
                            try:
                                self.export_safe_senders_to_yaml(safe_senders)
                                self.log_print(f"Appended to: {self.active_safe_senders_file}")
                            except Exception:
                                pass
                        elif response == 'sd':
                            # Add sender's domain as a regex to safe_senders (any local part, any subdomains)
                            domain_regex = self.build_sender_domain_safe_regex(from_domain or from_email)
                            if domain_regex:
                                if domain_regex not in safe_senders.get("safe_senders", []):
                                    safe_senders["safe_senders"].append(domain_regex)
                                self.log_print(f"Added sender-domain regex '{domain_regex}' to safe_senders list")
                                simple_print(f"Added sender-domain regex to safe_senders: {domain_regex}")
                                rule_updated = True
                                try:
                                    self.export_safe_senders_to_yaml(safe_senders)
                                    self.log_print(f"Appended to: {self.active_safe_senders_file}")
                                except Exception:
                                    pass

            except Exception as e:
                self.log_print(f"Error processing email for rule updates: {str(e)} {email_header}")
                simple_print(f"Error processing email: {str(e)}")

        self.log_print("Rule update process completed")
        simple_print("\nRule update process completed")
        return rules_json, safe_senders

    def check_phishing_indicators(self, email):
        """Check for phishing indicators in an email"""
        indicators = []

        try:
            # Check sender mismatch
            sender = email.SenderEmailAddress.lower()
            display_name = email.SenderName.lower()
            if '@' in display_name and display_name != sender:
                self.log_print(f"Phishing indicator: Sender name/email mismatch: {display_name} vs {sender}")
                indicators.append("Phishing indicator: Sender name/email mismatch")

            # Check urgent language
            urgent_words = ['urgent', 'immediate', 'action required', 'account suspended']
            found_urgent = [word for word in urgent_words if word in email.Subject.lower()]
            if found_urgent:
                self.log_print(f"Phishing indicator: Found urgent language in subject: {found_urgent}")
                indicators.append("Phishing indicator: Found urgent language in subject")

            # Check URLs
            if email.HTMLBody:
                href_pattern = r'href=[\'"]?([^\'" >]+)'
                urls = re.findall(href_pattern, email.HTMLBody)
                for url in urls:
                    if 'http' in url.lower():
                        if url.lower() not in email.HTMLBody.lower():
                            self.log_print(f"Phishing indicator: Found mismatched URL display text: {url}")
                            indicators.append("Phishing indicator: Found Mismatched URL display text")
                            break

            # Check sensitive words
            sensitive_words = ['password', 'login', 'credential', 'verify account']
            found_sensitive = [word for word in sensitive_words if word in email.Body.lower()]
            if found_sensitive:
                self.log_print(f"Phishing indicator: Found requests for sensitive information: {found_sensitive}")
                indicators.append("Phishing indicator: Found requests for sensitive information")

        except Exception as e:
            self.log_print(f"Error checking indicators: {str(e)}")

        return indicators

    def delete_email_with_retry(self, email, max_retries=10, delay=1):
        r"""
        Attempt to delete an email with retries.

        Args:
            email: The email object to delete.
            max_retries: Maximum number of retries.
            delay: Delay between retries in seconds.
        """

        import time

        # Prepare email for deletion - mark as read and clear flags
        try: #to mark email as read if unread
            if email.UnRead:
                self.mark_email_read_with_retry(email)
                # email.UnRead = False  # Delete implies marking the item as read
                self.log_print(f"Email marked as read", "DEBUG")
        except:
            self.log_print(f"Error marking email as read", "DEBUG")

        try: #to clear the flag on email
            if hasattr(email, 'Flag'):
                self.clear_email_flag_with_retry(email)
                # email.Flag.Clear()      # Delete implies clearing the flag
                self.log_print(f"Email flag was cleared", "DEBUG")
        except:
            self.log_print(f"Error clearing flag", "DEBUG")

        for attempt in range(max_retries):
            try:
                email.Delete()
                self.log_print(f"Email deleted successfully on attempt {attempt + 1}")
                return
            except Exception as e:
                self.log_print(f"Error deleting email on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    raise
        return

    def move_email_with_retry(self, email, target_folder, max_retries=10, delay=1):
        r"""
        Attempt to move an email to a target folder with retries.
        First it makes a copy of the email, then it moves it to the inbox
        Args:
            email: The email object to move.
            target_folder: The target folder to move the email to.
            max_retries: Maximum number of retries.
            delay: Delay between retries in seconds.
        """

        import time
        for attempt in range(max_retries):
            try:
                copied_email = email.Copy()
                copied_email.Move(target_folder)
                self.log_print(f"Email moved successfully to {target_folder.Name} on attempt {attempt + 1}")
                return
            except Exception as e:
                self.log_print(f"Error copying email on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    raise
        return

    def mark_email_read_with_retry(self, email, max_retries=10, delay=1):
        r"""
        Attempt to mark an email as unread with retries.

        Args:
            email: The email object to mark as unread.
        """

        import time
        for attempt in range(max_retries):
            try:
                if email.UnRead:
                    email.UnRead = False
                    email.Save()
                    self.log_print(f"Email marked as read successfully on attempt  {attempt + 1}")
                return
            except Exception as e:
                self.log_print(f"Error marking email as read on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    raise
        return

    def clear_email_flag_with_retry(self, email, max_retries=10, delay=1):
        r"""
        Attempt to clear the flag on an email; with with retries.

        Args:
            email: The email object to clear the flag.
        """

        import time
        for attempt in range(max_retries):
            try:
                email.Flag.Clear()
                # email.Save()
                self.log_print(f"Email flag cleared successfully on attempt  {attempt + 1}")
                return
            except Exception as e:
                self.log_print(f"Error clearing flag on email on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    raise
        return

    def assign_category_to_email_with_retry(self, email, category_name, max_retries=10, delay=1):
        r"""
        Attempt to mark an email as unread with retries.

        Args:
            email: The email object to mark as unread.
        """

        import time
        for attempt in range(max_retries):
            try:
                email.Categories = category_name
                email.Save()
                self.log_print(f"Email category {category_name} assigned successfully on attempt  {attempt + 1}")
                return
            except Exception as e:
                self.log_print(f"Error assigning {category_name} to email on attempt {attempt + 1}: {str(e)}")
                if attempt < max_retries - 1:
                    time.sleep(delay)
                else:
                    raise
        return

    def _get_emails_from_folder(self, folder, days_back):
        r"""Helper method to get emails from a specific folder for reprocessing"""
        try:
            # Create date restriction for recent emails
            restriction = "[ReceivedTime] >= '" + \
                (datetime.now() - timedelta(days=days_back)).strftime('%m/%d/%Y') + "'"
            emails = folder.Items.Restrict(restriction)
            
            if emails is None or emails.Count == 0:
                self.log_print(f"No emails found in folder: {folder.Name}")
                return []
            
            if isinstance(emails, str):
                self.log_print(f"Error: 'emails' is a string, expected a collection in folder: {folder.Name}")
                return []
            
            emails.Sort("[ReceivedTime]", Descending=True)
            self.log_print(f"Found {emails.Count} emails in folder {folder.Name} for reprocessing")
            
            # Convert to list for processing
            return [email for email in emails]
            
        except Exception as e:
            self.log_print(f"Error getting emails from folder {folder.Name}: {str(e)}")
            return []

    def _compile_pattern_list(self, patterns):
        compiled = []
        for p in patterns:
            try:
                # Treat patterns as full regex; ensure lowercased as input is normalized elsewhere
                compiled.append(re.compile(p, re.IGNORECASE))
            except re.error as e:
                self.log_print(f"Invalid regex skipped: {p} ({str(e)})")
        return compiled

    def _any_regex_match(self, compiled_patterns, text):
        tl = text or ""
        for pat in compiled_patterns:
            if pat.search(tl):
                return True, pat.pattern
        return False, None

    def _regex_match_header_any(self, compiled_patterns, email_header: str, sender_email: str):
        r"""Match only against the displayed tokens: From (sender email) and Domain (extracted).

        This aligns matching with what is printed during -u: "From:" and "Domain:",
        after stripping leading/trailing spaces.
        """
        if not compiled_patterns:
            return False, None
        from_tok = (self.header_from(email_header) or "").strip().lower()
        sender_tok = (sender_email or "").strip().lower()
        candidates = []
        if from_tok:
            candidates.append(from_tok)
        if sender_tok:
            candidates.append(sender_tok)
        for cand in candidates:
            m, pat = self._any_regex_match(compiled_patterns, cand)
            if m:
                return True, pat
        return False, None

    def process_emails(self, rules_json, safe_senders, days_back=DAYS_BACK_DEFAULT, update_rules=False, use_regex=False):
        """Process emails based on the rules in the rules_json object - now processes multiple folders"""
        self.log_print(f"\n\nStarting email processing")
        self.log_print(f"Target folders: {[folder.Name for folder in self.target_folders]}", "DEBUG")
        self.log_print(f"Processing emails from last {days_back} days")
        self.log_print(f"Regex mode: {'enabled' if use_regex else 'disabled'}")
        self.log_print(f"Matching semantics: regex (only supported mode)")
        self.log_print(f"Interactive rule updates: {'enabled' if update_rules else 'disabled'}")

        try:
            # Extract rules array if rules_json is a dictionary with a 'rules' key
            if isinstance(rules_json, dict) and "rules" in rules_json:
                rules = rules_json["rules"]
                # safe_senders = rules_json.get("safe_senders", [])
                self.log_print(f"Processing with {len(rules)} rules and {len(safe_senders["safe_senders"])} safe senders")
            else:
                # Handle direct rules array
                rules = rules_json if isinstance(rules_json, list) else [rules_json]
                # Don't reset safe_senders - keep the loaded safe_senders

            # Process emails from all target folders
            all_emails_to_process = []
            all_emails_added_info = []
            
            for target_folder in self.target_folders:
                self.log_print(f"Processing folder: {target_folder.Name}")
                
                # Get recent emails from the current target folder
                restriction = "[ReceivedTime] >= '" + \
                    (datetime.now() - timedelta(days=days_back)).strftime('%m/%d/%Y') + "'"
                emails = target_folder.Items.Restrict(restriction)

                if not emails:
                    self.log_print(f"No emails found to process in folder: {target_folder.Name}")
                    continue

                if isinstance(emails, str):
                    self.log_print(f"Error: 'emails' is a string, expected a collection of email objects in folder: {target_folder.Name}")
                    continue

                emails.Sort("[ReceivedTime]", Descending=True)
                self.log_print(f"Total emails found in {target_folder.Name}: {emails.Count}")

                # Create a list of emails to process from this folder
                folder_emails_to_process = [email for email in emails]
                folder_emails_added_info = [{
                    "match": False,
                    "rule": "",
                    "matched_keyword": "",
                    "indicators": [],
                    "email_header": "",
                    "processed": False,
                    "source_folder": target_folder.Name,  # Track which folder the email came from
                } for email in folder_emails_to_process]
                
                # Add to the combined lists
                all_emails_to_process.extend(folder_emails_to_process)
                all_emails_added_info.extend(folder_emails_added_info)

            if not all_emails_to_process:
                self.log_print("No emails found to process in any folders.")
                return

            processed_count = 0
            flagged_count = 0
            deleted_total = 0
            matched_emails = []
            non_matched_emails = []

            self.log_print(f"{CRLF}Beginning email analysis:")
            self.log_print(f"Total emails to process across all folders: {len(all_emails_to_process)}")

            # Sort rules once per first-pass (optimization: moved outside email loop)
            rules.sort(key=lambda rule: rule['actions'].get('delete', False))

            # Precompile safe sender patterns for regex mode
            compiled_safe_senders = []
            if use_regex:
                compiled_safe_senders = self._compile_pattern_list(safe_senders.get("safe_senders", []))

            for email in all_emails_to_process:
                try:
                    processed_count += 1
                    email_index = all_emails_to_process.index(email)
                    email_deleted = False
                    try:
                        raw_header = email.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E")
                        email_header = self.combine_email_header_lines(raw_header)
                    except Exception as e:
                        self.log_print(f"Error getting email header: {str(e)}")
                        email_header = ""
                    self.log_print(f"\n\nEmail {processed_count}:")
                    self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")
                    self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress).lower()}")
                    self.log_print(f"Received: {email.ReceivedTime}")
                    self.log_print(f"Source folder: {all_emails_added_info[email_index]['source_folder']}")

                    # Check each safe_senders before rules
                    # safe_senders only needs to be checked once
                    if use_regex:
                        matched_safe, matched_pat = self._regex_match_header_any(compiled_safe_senders, email_header, email.SenderEmailAddress)
                        if matched_safe:
                            self.log_print(f"Safe sender (regex) matched in header: {matched_pat}")
                            self.move_email_with_retry(email, self.inbox_folder)
                            self.delete_email_with_retry(email)
                            email_deleted = True
                            if email in all_emails_to_process:
                                all_emails_to_process.remove(email)
                            self.log_print(f"Email moved to inbox")
                            continue

                    for rule in rules:
                        if not isinstance(rule, dict) or 'actions' not in rule:
                            self.log_print(f"Invalid rule format: {rule}")
                            continue
                        if email_deleted:
                            continue  # Go to the next email if one rule deletes the current email
                        conditions = rule['conditions']
                        exceptions = rule['exceptions']
                        # print(rule, conditions) #can be used for extra debugging information
                        match = False

                        # Check 'from' addresses
                        if 'from' in conditions:
                            from_list = conditions['from']
                            sender_email_lower = email.SenderEmailAddress.lower()
                            if use_regex:
                                compiled = self._compile_pattern_list(from_list)
                                m, pat = self._any_regex_match(compiled, sender_email_lower)
                                if m:
                                    match = True
                                    matched_keyword = pat
                                    self.log_print(f"Matched regex in from address: {matched_keyword}")
                                    self.log_print(f"Rule matched: {rule['name']} via FROM pattern: {matched_keyword}")
                                    self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress)}")
                            else:
                                from_addresses = [addr.lower() for addr in from_list]
                                for addr in from_addresses:
                                    addr_lower = addr.lower()
                                    matched_simple = False
                                    if addr_lower.startswith('*'):
                                        pattern_without_wildcard = addr_lower[1:]
                                        if sender_email_lower.endswith(pattern_without_wildcard):
                                            matched_simple = True
                                    else:
                                        if addr_lower in sender_email_lower:
                                            matched_simple = True
                                    if matched_simple:
                                        match = True
                                        matched_keyword = addr
                                        self.log_print(f"Matched keyword in from address: {matched_keyword}")
                                        self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress)}")
                                        break

                        # Check 'subject' keywords
                        if 'subject' in conditions:
                            if use_regex:
                                compiled = self._compile_pattern_list(conditions['subject'])
                                m, pat = self._any_regex_match(compiled, email.Subject)
                                if m:
                                    match = True
                                    matched_keyword = pat
                                    self.log_print(f"Matched regex in subject: {matched_keyword}")
                                    self.log_print(f"Rule matched: {rule['name']} via SUBJECT pattern: {matched_keyword}")
                                    self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")
                            else:
                                if any(keyword.lower() in email.Subject.lower() for keyword in conditions['subject']):
                                    match = True
                                    matched_keyword = next((keyword for keyword in conditions['subject'] if keyword.lower() in email.Subject.lower()), None)
                                    self.log_print(f"Matched keyword in subject: {matched_keyword}")
                                    self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")

                        # Check 'body' keywords
                        if 'body' in conditions:
                            if use_regex:
                                compiled = self._compile_pattern_list(conditions['body'])
                                m, pat = self._any_regex_match(compiled, email.Body)
                                if m:
                                    match = True
                                    matched_keyword = pat
                                    self.log_print(f"Matched regex in body: {matched_keyword}")
                                    self.log_print(f"Rule matched: {rule['name']} via BODY pattern: {matched_keyword}")
                                    matched_lines = [line for line in email.Body.splitlines() if re.search(pat, line, re.IGNORECASE)]
                                    if matched_lines:
                                        self.log_print(f"First line of body that matches the regex: {matched_lines[0]}")
                            else:
                                if any(keyword.lower() in email.Body.lower() for keyword in conditions['body']):
                                    match = True
                                    matched_keyword = next((keyword for keyword in conditions['body'] if keyword.lower() in email.Body.lower()), None)
                                    self.log_print(f"Matched keyword in body: {matched_keyword}")
                                    matched_lines = [line for line in email.Body.splitlines() if matched_keyword.lower() in line.lower()]
                                    if matched_lines:
                                        self.log_print(f"First line of body that matches the keyword: {matched_lines[0]}")
                                # below will print all the body lines that match if needed for debugging
                                if DEBUG:
                                    for line in email.Body.splitlines():
                                        if any(keyword.lower() in line.lower() for keyword in conditions['body']):
                                            self.log_print(f"Body: {line}", "DEBUG")
                        # Check 'header' keywords
                        if 'header' in conditions:
                            if use_regex:
                                compiled = self._compile_pattern_list(conditions['header'])
                                m, pat = self._regex_match_header_any(compiled, email_header, email.SenderEmailAddress)
                                if m:
                                    match = True
                                    matched_keyword = pat
                                    self.log_print(f"Matched regex in header: {matched_keyword}")
                                    self.log_print(f"Rule matched: {rule['name']} via HEADER pattern: {matched_keyword}")
                                    # No need to scan header lines; match is against tokens only

                        # Check exceptions
                        if match and 'from' in exceptions:
                            from_addresses = [addr.lower() for addr in exceptions['from']]
                            sender_email_lower = email.SenderEmailAddress.lower()
                            
                            if use_regex:
                                compiled = self._compile_pattern_list(from_addresses)
                                m, pat = self._any_regex_match(compiled, sender_email_lower)
                                if m:
                                    match = False
                                    matched_keyword = pat
                                    self.log_print(f"Exception matched regex in from address: {matched_keyword}")
                                    self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress)}")
                            else:
                                for addr in from_addresses:
                                    addr_lower = addr.lower()
                                    exception_matched = False
                                    if addr_lower.startswith('*'):
                                        pattern_without_wildcard = addr_lower[1:]
                                        if sender_email_lower.endswith(pattern_without_wildcard):
                                            exception_matched = True
                                    else:
                                        if addr_lower in sender_email_lower:
                                            exception_matched = True
                                    if exception_matched:
                                        match = False
                                        matched_keyword = addr
                                        self.log_print(f"Exception matched keyword in from address: {matched_keyword}")
                                        self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress)}")
                                        break

                        # Check subject keywords in exceptions
                        if match and 'subject' in exceptions:
                            if use_regex:
                                compiled = self._compile_pattern_list(exceptions['subject'])
                                m, pat = self._any_regex_match(compiled, email.Subject)
                                if m:
                                    match = False
                                    matched_keyword = pat
                                    self.log_print(f"Exception matched regex in subject: {matched_keyword}")
                                    self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")
                            else:
                                if any(keyword.lower() in email.Subject.lower() for keyword in exceptions['subject']):
                                    match = False
                                    matched_keyword = next((keyword for keyword in exceptions['subject'] if keyword.lower() in email.Subject.lower()), None)
                                    self.log_print(f"Exception matched keyword in subject: {matched_keyword}")
                                    self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")

                        # Check body keywords in exceptions
                        if match and 'body' in exceptions:
                            if use_regex:
                                compiled = self._compile_pattern_list(exceptions['body'])
                                m, pat = self._any_regex_match(compiled, email.Body)
                                if m:
                                    match = False
                                    matched_keyword = pat
                                    self.log_print(f"Exception matched regex in body: {matched_keyword}")
                                    self.log_print(f"Body: {self._sanitize_string(email.Body)}")
                            else:
                                if any(keyword.lower() in email.Body.lower() for keyword in exceptions['body']):
                                    match = False
                                    matched_keyword = next((keyword for keyword in exceptions['body'] if keyword.lower() in email.Body.lower()), None)
                                    self.log_print(f"Exception matched keyword in body: {matched_keyword}")
                                    self.log_print(f"Body: {self._sanitize_string(email.Body)}")

                        # Check header keywords in exceptions
                        if match and 'header' in exceptions:
                            if use_regex:
                                compiled = self._compile_pattern_list(exceptions['header'])
                                m, pat = self._regex_match_header_any(compiled, email_header, email.SenderEmailAddress)
                                if m:
                                    match = False
                                    matched_keyword = pat
                                    self.log_print(f"Exception matched regex in header: {matched_keyword}")
                                    # Match was against tokens; no need to list header lines

                        # If match is true need to process 2 things, but do them in separate steps
                        # first, if matched save in the copy of emails, add the rule and the keyword matched
                        #   If not matched, will pull the information from the email
                        # can use the original email if the index is available - can use the index of all_emails_added_info
                        if match:
                            all_emails_added_info[email_index]["match"] = match
                            all_emails_added_info[email_index]["rule"] = rule
                            all_emails_added_info[email_index]["matched_keyword"] = matched_keyword
                            all_emails_added_info[email_index]["email_header"] = email_header
                            all_emails_added_info[email_index]["processed"] = True
                        else:
                            all_emails_added_info[email_index]["match"] = match
                            all_emails_added_info[email_index]["rule"] = None
                            all_emails_added_info[email_index]["matched_keyword"] = ""
                            all_emails_added_info[email_index]["email_header"] = email_header
                            all_emails_added_info[email_index]["processed"] = True

                        if match:
                            self.log_print(f"Email matches rule: {rule['name']}")
                            # Perform actions based on the rule
                            actions = rule['actions']
                            self.log_print(f"Performing actions: {actions}")

                            if 'assign_to_category' in actions and actions['assign_to_category']['category_name']:
                                try: # to assign category based on rule name
                                    category_name = actions['assign_to_category']['category_name']
                                    self.assign_category_to_email_with_retry(email, category_name)
                                    self.log_print(f"Email assigned to category '{category_name}'", "DEBUG")
                                except Exception as e:
                                    self.log_print(f"Error assigning category to email: {str(e)}")
                                if email.UnRead:
                                    self.mark_email_read_with_retry(email)
                                    self.log_print("Email marked as read")
                            if 'clear_flag' in actions and actions['clear_flag']:
                                # this flag is not being passed by outlook, so will never be set.  Keeping in case fixed in the future
                                self.clear_email_flag_with_retry(email)
                                self.log_print("Email flag cleared")
                            if 'set_importance' in actions and actions['set_importance']['importance_level']:
                                email.Importance = actions['set_importance']['importance_level']
                                email.Save()
                                self.log_print(f"Email importance set to {actions['set_importance']['importance_level']}")
                            if 'set_sensitivity' in actions and actions['set_sensitivity']['sensitivity_level']:
                                email.Sensitivity = actions['set_sensitivity']['sensitivity_level']
                                email.Save()
                                self.log_print(f"Email sensitivity set to {actions['set_sensitivity']['sensitivity_level']}")
                            if 'mark_as_task' in actions and actions['mark_as_task']['task_due_date']:
                                email.TaskDueDate = actions['mark_as_task']['task_due_date']
                                email.Save()
                                self.log_print(f"Email marked as task with due date: {actions['mark_as_task']['task_due_date']}")
                            if 'play_sound' in actions and actions['play_sound']['sound_file']:
                                import winsound
                                winsound.PlaySound(actions['play_sound']['sound_file'], winsound.SND_FILENAME)
                                self.log_print(f"Played sound: {actions['play_sound']['sound_file']}")
                            if 'display_desktop_alert' in actions and actions['display_desktop_alert']:
                                self.log_print("Desktop alert displayed")
                                # Implement desktop alert display logic here
                            if 'copy_to_folder' in actions and actions['copy_to_folder']['folder_name']:
                                folder_name = actions['copy_to_folder']['folder_name']
                                target_folder = self._get_account_folder(self.email_address, folder_name)
                                email.Copy().Move(target_folder)
                                self.log_print(f"Email copied to '{folder_name}' folder")
                            if 'forward' in actions and actions['forward']:
                                forward_recipients = [recipient['address'] for recipient in actions['forward']]
                                forward_email = email.Forward()
                                forward_email.To = ";".join(forward_recipients)
                                forward_email.Send()
                                self.log_print(f"Email forwarded to: {', '.join(forward_recipients)}")
                            if 'reply' in actions and actions['reply']['template']:
                                reply_email = email.Reply()
                                reply_email.Body = actions['reply']['template']
                                reply_email.Send()
                                self.log_print("Auto-reply sent")
                            if 'redirect' in actions and actions['redirect']:
                                redirect_recipients = [recipient['address'] for recipient in actions['redirect']]
                                redirect_email = email.Forward()
                                redirect_email.To = ";".join(redirect_recipients)
                                redirect_email.Send()
                                self.log_print(f"Email redirected to: {', '.join(redirect_recipients)}")
                            if 'print' in actions and actions['print']:
                                email.PrintOut()
                                self.log_print("Email printed")
                            if 'run_script' in actions and actions['run_script']['script_path']:
                                exec(open(actions['run_script']['script_path']).read())
                                self.log_print(f"Script executed: {actions['run_script']['script_path']}")
                            if 'start_application' in actions and actions['start_application']['application_path']:
                                import subprocess
                                subprocess.Popen(actions['start_application']['application_path'])
                                self.log_print(f"Application started: {actions['start_application']['application_path']}")
                            if 'move_to_folder' in actions and actions['move_to_folder']['folder_name']:
                                folder_name = actions['move_to_folder']['folder_name']
                                target_folder = self._get_account_folder(self.email_address, folder_name)
                                email.Move(target_folder)
                                self.log_print(f"Email moved to '{folder_name}' folder")
                            if 'stop_processing_more_rules' in actions and actions['stop_processing_more_rules']:
                                self.log_print("Stopping processing more rules")
                                # this flag is not being passed by outlook, so will never be set.  Keeping in case fixed in the future
                            if 'delete' in actions and actions['delete']:
                                try: # to delete email
                                    self.delete_email_with_retry(email)
                                    email_deleted = True
                                    deleted_total += 1
                                    self.log_print("Email marked as read, flag cleared and deleted")
                                    # self.simple_print(f"Deleted email from: {self._sanitize_string(email.SenderEmailAddress)}")
                                    # delete implies "Stop Processing More Rules".  Continue will go to next email
                                except Exception as e:
                                    self.log_print(f"Error deleting email: {str(e)}")

                                break # If delete, then process no more rules and go to next email
                            continue  # Go to the next email if one rule matches

                    # After all email rules are processed and it did not match any rules and the email has not been deleted, then check for phishing indicators
                    if not (email_deleted):
                        indicators = self.check_phishing_indicators(email)
                        if indicators:
                            flagged_count += 1
                            self.log_print(f"Phishing indicators found: {indicators}")
                            all_emails_added_info[email_index]["phishing_indicators"] = indicators
                        else:
                            self.log_print("No conditions or phishing indicators found")
                            # Optional DEBUG: When in regex mode, show the sender and the first few FROM patterns to help diagnose misses
                            if use_regex and all_emails_added_info[email_index]["match"] == False:
                                try:
                                    preview_k = 5
                                    from_patterns = []
                                    for r in rules:
                                        vals = (r.get('conditions') or {}).get('from')
                                        if isinstance(vals, list):
                                            from_patterns.extend(vals)
                                    self.log_print(
                                        f"DEBUG no-match: sender={self._sanitize_string(email.SenderEmailAddress).lower()} | top FROM patterns={from_patterns[:preview_k]}",
                                        level="DEBUG"
                                    )
                                except Exception:
                                    pass
                        # If it is in the Bulk Mail folder, but nothing indicated via rules or phishing,
                        # show the body and header, so we information needed to add it to a rule
                        for line in email.Body.splitlines():
                            self.log_print(f"Body: {line}")
                        for header in email_header.splitlines():
                            self.log_print(f"Header: {header}")

                    if (DEBUG) and (processed_count >= DEBUG_EMAILS_TO_PROCESS):
                        self.log_print(f"Debug mode: Stopping after {DEBUG_EMAILS_TO_PROCESS} emails")
                        break  # Stop processing more emails in debug mode, then write the report and prompt for rule updates

                except Exception as e:
                    self.log_print(f"Error processing email: {str(e)}")


            # Print a list for Phishing OR Match=false, report body unique URL stubs "/<domain>.<>" and ".<domain>.<>" so they can be easily added to the rules
            #     collect them all first, then determine uniqueness, then print one per line
            self.log_print(f"\nProcessing Report of URL's from phishing or match = False")
            self.URL_report(all_emails_to_process, all_emails_added_info)

            # Print a list for Phishing OR Match=false with From: "@<domain>.<>" so they can be easily added to the rules
            self.log_print(f"\nProcessing Report of From's from phishing or match = False")
            self.from_report(all_emails_to_process, all_emails_added_info, rules_json)

            # After processing all emails, prompt for rule updates based on unfiltered emails
            if processed_count > 0:
                self.log_print(f"{CRLF}Checking for rule updates based on unfiltered emails...")
                # Original call to prompt_update_rules (commented out)
                # rules_json, safe_senders = self.prompt_update_rules(all_emails_to_process, all_emails_added_info, rules_json, safe_senders)
                
                # New conditional call based on command line argument
                if update_rules:
                    self.log_print(f"Interactive rule updates enabled - prompting for rule updates...")
                    rules_json, safe_senders = self.prompt_update_rules(all_emails_to_process, all_emails_added_info, rules_json, safe_senders)
                else:
                    self.log_print(f"Interactive rule updates disabled (use -u or --update_rules to enable)")

            # Second-pass processing: Reprocess all emails in bulk folders after rule updates
            self.log_print(f"{CRLF}Starting second-pass email processing after rule updates...")
            simple_print(f"\nStarting second-pass email processing...")
            
            # Get fresh emails from all bulk folders for second-pass processing
            second_pass_emails = []
            second_pass_added_info = []
            
            for folder_name in EMAIL_BULK_FOLDER_NAMES:
                bulk_folder = self._get_account_folder(self.email_address, folder_name)
                if bulk_folder:
                    self.log_print(f"Second-pass: Processing folder '{folder_name}' (found: {bulk_folder.Name})")
                    
                    # Get emails from this folder for second-pass
                    folder_emails = self._get_emails_from_folder(bulk_folder, days_back)
                    
                    for email in folder_emails:
                        second_pass_emails.append(email)
                        # Create basic info structure for second-pass emails
                        email_info = {
                            "match": False,
                            "rule": None,
                            "matched_keyword": "",
                            "email_header": "",
                            "processed": False,
                            "phishing_indicators": [],
                            "source_folder": bulk_folder.Name
                        }
                        second_pass_added_info.append(email_info)
                else:
                    self.log_print(f"Second-pass: Folder '{folder_name}' not found, skipping")
            
            self.log_print(f"Second-pass: Found {len(second_pass_emails)} emails to reprocess")
            simple_print(f"Second-pass: Found {len(second_pass_emails)} emails to reprocess")
            
            # Precompile safe sender patterns for regex mode (second pass may include updates)
            second_pass_compiled_safe_senders = []
            if use_regex:
                second_pass_compiled_safe_senders = self._compile_pattern_list(safe_senders.get("safe_senders", []))

            # Process second-pass emails if any found
            if second_pass_emails:
                second_pass_processed = 0
                second_pass_deleted = 0
                second_pass_flagged = 0
                
                # Sort rules once per second-pass (optimization: moved outside email loop)
                rules.sort(key=lambda rule: rule['actions'].get('delete', False))
                
                for email_index, email in enumerate(second_pass_emails):
                    try:
                        if email_index >= len(second_pass_added_info):
                            continue  # Safety check
                        
                        email_deleted = False
                        email_header = self.combine_email_header_lines(email.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E"))
                        second_pass_added_info[email_index]["email_header"] = email_header
                        
                        self.log_print(f"Second-pass processing email {email_index + 1}/{len(second_pass_emails)}")
                        self.log_print(f"Subject: {self._sanitize_string(email.Subject)}")
                        self.log_print(f"From: {self._sanitize_string(email.SenderEmailAddress).lower()}")
                        
                        # Check safe senders first (mirror first-pass logic)
                        if use_regex:
                            matched_safe, matched_pat = self._regex_match_header_any(second_pass_compiled_safe_senders, email_header, email.SenderEmailAddress)
                            if matched_safe:
                                self.log_print(f"Second-pass: Safe sender (regex) matched in header: {matched_pat}")
                                self.move_email_with_retry(email, self.inbox_folder)
                                self.delete_email_with_retry(email)
                                email_deleted = True
                        
                        if email_deleted:
                            second_pass_processed += 1
                            second_pass_deleted += 1
                            continue
                        
                        # Process rules (mirror first-pass logic; regex-aware)
                        for rule in rules:
                            if not isinstance(rule, dict) or 'actions' not in rule:
                                continue
                            if email_deleted:
                                continue
                            
                            conditions = rule['conditions']
                            exceptions = rule['exceptions']
                            
                            match = False
                            matched_keyword = ""

                            # FROM
                            if 'from' in conditions and not match:
                                sender_email_lower = (email.SenderEmailAddress or '').lower()
                                if use_regex:
                                    compiled = self._compile_pattern_list(conditions['from'])
                                    m, pat = self._any_regex_match(compiled, sender_email_lower)
                                    if m:
                                        match = True
                                        matched_keyword = pat
                                        self.log_print(f"Second-pass: Matched regex in from address: {matched_keyword}")
                                else:
                                    from_addresses = [addr.lower() for addr in conditions['from']]
                                    for addr in from_addresses:
                                        addr_lower = addr.lower()
                                        matched_simple = False
                                        if addr_lower.startswith('*'):
                                            pattern_without_wildcard = addr_lower[1:]
                                            if sender_email_lower.endswith(pattern_without_wildcard):
                                                matched_simple = True
                                        else:
                                            if addr_lower in sender_email_lower:
                                                matched_simple = True
                                        if matched_simple:
                                            match = True
                                            matched_keyword = addr
                                            break

                            # SUBJECT
                            if 'subject' in conditions and not match:
                                if use_regex:
                                    compiled = self._compile_pattern_list(conditions['subject'])
                                    m, pat = self._any_regex_match(compiled, email.Subject)
                                    if m:
                                        match = True
                                        matched_keyword = pat
                                        self.log_print(f"Second-pass: Matched regex in subject: {matched_keyword}")
                                else:
                                    if any(keyword.lower() in email.Subject.lower() for keyword in conditions['subject']):
                                        match = True
                                        matched_keyword = next((keyword for keyword in conditions['subject'] if keyword.lower() in email.Subject.lower()), None)

                            # BODY
                            if 'body' in conditions and not match:
                                if use_regex:
                                    compiled = self._compile_pattern_list(conditions['body'])
                                    m, pat = self._any_regex_match(compiled, email.Body)
                                    if m:
                                        match = True
                                        matched_keyword = pat
                                        self.log_print(f"Second-pass: Matched regex in body: {matched_keyword}")
                                else:
                                    if any(keyword.lower() in email.Body.lower() for keyword in conditions['body']):
                                        match = True
                                        matched_keyword = next((keyword for keyword in conditions['body'] if keyword.lower() in email.Body.lower()), None)

                            # HEADER
                            if 'header' in conditions and not match:
                                if use_regex:
                                    compiled = self._compile_pattern_list(conditions['header'])
                                    m, pat = self._regex_match_header_any(compiled, email_header, email.SenderEmailAddress)
                                    if m:
                                        match = True
                                        matched_keyword = pat
                                        self.log_print(f"Second-pass: Matched regex in header: {matched_keyword}")

                            # Exceptions
                            if match and 'from' in exceptions:
                                sender_email_lower = (email.SenderEmailAddress or '').lower()
                                if use_regex:
                                    compiled = self._compile_pattern_list(exceptions['from'])
                                    m, pat = self._any_regex_match(compiled, sender_email_lower)
                                    if m:
                                        match = False
                                        matched_keyword = pat
                                else:
                                    from_addresses = [addr.lower() for addr in exceptions['from']]
                                    for addr in from_addresses:
                                        addr_lower = addr.lower()
                                        exception_matched = False
                                        if addr_lower.startswith('*'):
                                            pattern_without_wildcard = addr_lower[1:]
                                            if sender_email_lower.endswith(pattern_without_wildcard):
                                                exception_matched = True
                                        else:
                                            if addr_lower in sender_email_lower:
                                                exception_matched = True
                                        if exception_matched:
                                            match = False
                                            matched_keyword = addr
                                            break

                            if match and 'subject' in exceptions:
                                if use_regex:
                                    compiled = self._compile_pattern_list(exceptions['subject'])
                                    m, pat = self._any_regex_match(compiled, email.Subject)
                                    if m:
                                        match = False
                                        matched_keyword = pat
                                else:
                                    if any(keyword.lower() in email.Subject.lower() for keyword in exceptions['subject']):
                                        match = False
                                        matched_keyword = next((keyword for keyword in exceptions['subject'] if keyword.lower() in email.Subject.lower()), None)

                            if match and 'body' in exceptions:
                                if use_regex:
                                    compiled = self._compile_pattern_list(exceptions['body'])
                                    m, pat = self._any_regex_match(compiled, email.Body)
                                    if m:
                                        match = False
                                        matched_keyword = pat
                                else:
                                    if any(keyword.lower() in email.Body.lower() for keyword in exceptions['body']):
                                        match = False
                                        matched_keyword = next((keyword for keyword in exceptions['body'] if keyword.lower() in email.Body.lower()), None)

                            if match and 'header' in exceptions:
                                if use_regex:
                                    compiled = self._compile_pattern_list(exceptions['header'])
                                    m, pat = self._regex_match_header_any(compiled, email_header, email.SenderEmailAddress)
                                    if m:
                                        match = False
                                        matched_keyword = pat
                            
                            # Update email info
                            if match:
                                second_pass_added_info[email_index]["match"] = True
                                second_pass_added_info[email_index]["rule"] = rule
                                second_pass_added_info[email_index]["matched_keyword"] = matched_keyword
                                second_pass_added_info[email_index]["processed"] = True

                                self.log_print(f"Second-pass: Email matches rule: {rule['name']}")

                                # Process actions (focus on delete action for second pass)
                                actions = rule['actions']
                                if 'delete' in actions and actions['delete']:
                                    try:
                                        self.delete_email_with_retry(email)
                                        email_deleted = True
                                        second_pass_deleted += 1
                                        self.log_print(f"Second-pass: Email deleted by rule: {rule['name']}")
                                        break
                                    except Exception as e:
                                        self.log_print(f"Second-pass: Error deleting email: {str(e)}")
                        
                        # Check phishing indicators for unmatched emails
                        if not email_deleted and not second_pass_added_info[email_index]["match"]:
                            indicators = self.check_phishing_indicators(email)
                            if indicators:
                                second_pass_flagged += 1
                                self.log_print(f"Second-pass: Phishing indicators found: {indicators}")
                                second_pass_added_info[email_index]["phishing_indicators"] = indicators
                        
                        second_pass_processed += 1
                        
                        if (DEBUG) and (second_pass_processed >= DEBUG_EMAILS_TO_PROCESS):
                            self.log_print(f"Second-pass debug mode: Stopping after {DEBUG_EMAILS_TO_PROCESS} emails")
                            break
                    
                    except Exception as e:
                        self.log_print(f"Second-pass: Error processing email: {str(e)}")
                
                # Log second-pass summary

                print_to(f"\nSecond-pass Processing Summary:", to_log=True, to_simple=True, to_console=True, log_instance=self)
                print_to(f"Second-pass processed {second_pass_processed:>3} emails", to_log=True, to_simple=True, to_console=True, log_instance=self)
                print_to(f"Second-pass flagged   {second_pass_flagged:>3} emails as possible Phishing attempts", to_log=True, to_simple=True, to_console=True, log_instance=self)
                print_to(f"Second-pass deleted   {second_pass_deleted:>3} emails", to_log=True, to_simple=True, to_console=True, log_instance=self)

                # Update total counts to include second-pass results
                processed_count += second_pass_processed
                deleted_total += second_pass_deleted
                flagged_count += second_pass_flagged
            else:
                self.log_print(f"Second-pass: No emails found for reprocessing")
                simple_print(f"Second-pass: No emails found for reprocessing")

            print_to(f"\nFinal Processing Summary (including second-pass):", to_log=True, to_simple=True, to_console=True, log_instance=self)
            print_to(f"Total processed {processed_count:>3} emails", to_log=True, to_simple=True, to_console=True, log_instance=self)
            print_to(f"Total flagged   {flagged_count:>3} emails as possible Phishing attempts", to_log=True, to_simple=True, to_console=True, log_instance=self)
            print_to(f"Total deleted   {deleted_total:>3} emails", to_log=True, to_simple=True, to_console=True, log_instance=self)
            self.log_print(f"END of Run =============================================================\n\n")

        except Exception as e:
            self.log_print(f"Error in process_emails: {str(e)}")
            raise



# Main program execution --------------------------------------------------------
def main():
    """Main function to run the security agent"""
    
    # Add argument parsing
    parser = argparse.ArgumentParser(description='Outlook Mail Spam Filter')
    parser.add_argument('-u', '--update_rules', action='store_true', 
                       help='Enable interactive rule updates (default: disabled)')
    
    # Backward-compat shim: ignore removed flags if present on CLI to prevent argparse errors
    removed_cli_flags = ['--use-regex-files', '--convert-safe-senders-to-regex', '--convert-rules-to-regex']
    for _flag in list(removed_cli_flags):
        if _flag in sys.argv:
            print(f"Warning: {_flag} is deprecated and ignored. Regex mode is always on; conversion utilities are removed.")
            try:
                sys.argv.remove(_flag)
            except ValueError:
                pass
    
    args = parser.parse_args()

    # Initialize agent
    agent = OutlookSecurityAgent()  # setup for calling functions in class OutlookSecurityAgent

    try:

        print_to(f"\n=============================================================", 
                 to_log=True, to_simple=True, log_instance=agent)
        print_to(f"Starting Outlook Security Agent at {datetime.now().strftime('%m/%d/%Y %I:%M:%S %p')}", 
                 to_log=True, to_simple=True, to_console=True, log_instance=agent)
        print_to(f"This will make changes", 
                 to_log=True, to_simple=True, log_instance=agent)
        print_to(f"Check the {OUTLOOK_SECURITY_LOG} for detailed information", 
                 to_log=True, to_simple=True, log_instance=agent)

        # Always use regex mode now
        effective_use_regex_files = True

        # Set mode and log file paths
        agent.set_active_mode(effective_use_regex_files)

        # Load rules using active files
        rules_json, safe_senders = agent.get_rules(use_regex_files=effective_use_regex_files)

        # Process last N days of emails - see DAYS_BACK_DEFAULT
        agent.log_print(f"{CRLF}Begin email analysis{CRLF}")

        agent.process_emails(rules_json, safe_senders, update_rules=args.update_rules, use_regex=effective_use_regex_files)

        agent.log_print(f"{CRLF}End email analysis{CRLF}")

        # Export rules every time (saving copies to backups to Archive directory)
        agent.export_rules_to_yaml(rules_json)  # defaults to agent.active_rules_file

        agent.export_safe_senders_to_yaml(safe_senders)  # defaults to agent.active_safe_senders_file

        print_to(f"Execution complete at {datetime.now().strftime('%m/%d/%Y %I:%M:%S %p')}. Check the log file for detailed analysis:\n{OUTLOOK_SECURITY_LOG}", 
                 to_log=True, to_simple=True, to_console=True, log_instance=agent)
        print_to(f"=============================================================\n", 
                 to_log=True, to_simple=True, to_console=True, log_instance=agent)

    except Exception as e:
        simple_print(f"\nError: {str(e)}")
        logging.error(f"Main execution error: {str(e)}")

if __name__ == "__main__":
    main()
