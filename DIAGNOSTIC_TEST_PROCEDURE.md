# Diagnostic Test Procedure: Zero Rules Match Issue

**Purpose**: Identify why AOL "Bulk Mail Testing" folder shows "No Rules: 335"

**Requirements**:
- Built app with diagnostic logging (commit 307b747)
- Android emulator or device with app installed
- `adb` command available
- AOL account credentials (kimmeyharold@aol.com)

---

## Quick Start (5 minutes)

### 1. Start Fresh Logs
```bash
# Clear previous logs
adb logcat -c

# Start capturing logs to file
adb logcat > diagnostic_scan.log &
```

### 2. Run Bulk Mail Scan
1. In app: Go to Account Selection → Select kimmeyharold@aol.com
2. Select "Start Live Scan" (not Demo Scan)
3. Choose "Bulk Mail Testing" folder
4. Wait for scan to complete or get to ~10 emails processed
5. Note the results screen

### 3. Stop Logs
```bash
# Stop the logcat process
pkill -f "adb logcat"

# View captured logs
```

---

## Analysis: What to Look For

### Expected Log Output

#### ✓ If Rules Loaded Successfully
```
I/SCAN DIAGNOSTICS: === SCAN DIAGNOSTICS ===
I/SCAN DIAGNOSTICS: Rules loaded: 47
I/SCAN DIAGNOSTICS: Safe senders loaded: 12
I/SCAN DIAGNOSTICS: RuleSetProvider state: isLoading=false, isError=false, error=null
I/SCAN DIAGNOSTICS: First rule: SpamAutoDeleteHeader (enabled=true)
I/SCAN DIAGNOSTICS: =======================
I/RuleEvaluator: ✓ Email "Subject line..." matched rule "SpamAutoDeleteHeader"
I/RuleEvaluator: ✓ Email "Another subject..." matched rule "MarketingBulkMove"
...
D/RuleEvaluator: ✗ Email "No match subject..." did not match any of 47 enabled rules
```

#### ❌ If Rules NOT Loaded (0 Rules)
```
I/SCAN DIAGNOSTICS: === SCAN DIAGNOSTICS ===
I/SCAN DIAGNOSTICS: Rules loaded: 0
I/SCAN DIAGNOSTICS: Safe senders loaded: 0
I/SCAN DIAGNOSTICS: RuleSetProvider state: isLoading=false, isError=false, error=null
I/SCAN DIAGNOSTICS: =======================
W/RuleEvaluator: RuleEvaluator: No rules available for evaluation of "Subject..."
```
**Action**: Rules are not being loaded. Check migration logs.

#### ⚠️ If Rules Disabled (All enabled=false)
```
I/SCAN DIAGNOSTICS: === SCAN DIAGNOSTICS ===
I/SCAN DIAGNOSTICS: Rules loaded: 47
...
I/SCAN DIAGNOSTICS: First rule: SpamAutoDeleteHeader (enabled=false)
I/SCAN DIAGNOSTICS: =======================
D/RuleEvaluator: Rule "SpamAutoDeleteHeader" is disabled, skipping
D/RuleEvaluator: Rule "MarketingBulkMove" is disabled, skipping
...
D/RuleEvaluator: ✗ Email "Subject..." did not match any of 0 enabled rules
```
**Action**: Rules exist but are all disabled. Check database enabled flags.

#### 🔍 If Rules Exist but Don't Match
```
I/SCAN DIAGNOSTICS: === SCAN DIAGNOSTICS ===
I/SCAN DIAGNOSTICS: Rules loaded: 47
...
D/RuleEvaluator: ✗ Email "Subject from Bulk Mail..." did not match any of 47 enabled rules
D/RuleEvaluator: ✗ Email "Another Bulk Mail..." did not match any of 47 enabled rules
... (all no matches)
```
**Action**: Rules are loaded and enabled, but don't match Bulk Mail content. Email structure issue.

---

## Filtering Logs for Analysis

### Get Just the Diagnostic Output
```bash
grep -i "SCAN DIAGNOSTICS\|RuleEvaluator" diagnostic_scan.log | head -20
```

### Count Matches vs No Matches
```bash
echo "=== MATCHES ==="
grep "✓ Email.*matched rule" diagnostic_scan.log | wc -l
echo "=== NO MATCHES ==="
grep "✗ Email.*did not match" diagnostic_scan.log | wc -l
```

### Check Migration Logs
```bash
grep -i "migration\|YAML\|migrate" diagnostic_scan.log
```

### Check Database Initialization
```bash
grep -i "database\|queryRules\|loading rules" diagnostic_scan.log
```

---

## Common Issues & Fixes

### Issue 1: "Rules loaded: 0"
**Cause**: Migration never ran or YAML files don't exist
**Fix Options**:
- Reinstall app (clears database)
- Ensure rules.yaml is in app directory
- Check app log for migration errors
- See Issue #71 fix (commit 43f1c0a)

### Issue 2: "Rules loaded: 47" but "enabled=false"
**Cause**: All rules in database have enabled flag set to 0
**Fix Options**:
- Check rules.yaml - are rules enabled there?
- Check database migration - did it import enabled status correctly?
- Manually enable rules via database

### Issue 3: "Rules loaded: 47" but all "✗ did not match"
**Cause**: Rule patterns don't match Bulk Mail email content
**Fix Options**:
- Compare INBOX emails vs Bulk Mail emails
- Check what headers/content exists in Bulk Mail
- Verify rule patterns are correct
- Log email properties to debug matching

### Issue 4: Logs show "No rules available"
**Cause**: RuleSet is empty or null
**Fix Options**:
- Check RuleSetProvider initialization
- Verify database connection
- Check if migration ran successfully

---

## If You Can Help: Questions to Answer

From the log output, please answer:

1. **How many rules loaded?**
   - Look for: `Rules loaded: X`
   - Expected: 40-50+ rules

2. **Are rules enabled?**
   - Look for: `First rule: ... (enabled=X)`
   - Expected: enabled=true

3. **Are any emails matching rules?**
   - Count lines with: `✓ Email ... matched rule`
   - Expected: Most Bulk Mail emails should match

4. **Migration status?**
   - Look for: Migration-related log messages
   - Expected: See migration completion logs on first run

5. **Any error messages?**
   - Look for: ERROR, EXCEPTION, failed
   - Expected: None

---

## Email Scanner Diagnostics Log Example

Here's what you'll see when scanning with 10 emails:

```
I/SCAN DIAGNOSTICS: === SCAN DIAGNOSTICS ===
I/SCAN DIAGNOSTICS: Rules loaded: 47
I/SCAN DIAGNOSTICS: Safe senders loaded: 12
I/SCAN DIAGNOSTICS: RuleSetProvider state: isLoading=false, isError=false, error=null
I/SCAN DIAGNOSTICS: First rule: SpamAutoDeleteHeader (enabled=true)
I/SCAN DIAGNOSTICS: =======================
I/RuleEvaluator: ✓ Email "Great offer inside!" matched rule "MarketingBulkMove"
D/RuleEvaluator: ✗ Email "Legitimate newsletter" did not match any of 47 enabled rules
I/RuleEvaluator: ✓ Email "Click here now!!!" matched rule "SpamAutoDeleteHeader"
...
```

---

## Next Steps After Diagnosis

Once you run the diagnostic scan and share the logs, I can:

1. **If 0 rules loaded**: Fix migration or database initialization
2. **If rules disabled**: Fix the enabled flag in database or YAML import
3. **If no matching**: Debug rule patterns against actual Bulk Mail email content
4. **If error messages**: Fix specific errors from logs

**Time to fix**: Once root cause is identified, fix usually takes 15-30 minutes

---

## Related Documentation

- **INVESTIGATION_RULES_ZERO_MATCHES.md** - Full technical investigation
- **Issue #71 Fix** - Commit 43f1c0a (YAML to database migration)
- **RuleEvaluator** - mobile-app/lib/core/services/rule_evaluator.dart
- **EmailScanner** - mobile-app/lib/core/services/email_scanner.dart

---

## Build & Deploy

If you haven't built with the diagnostic code yet:

```bash
cd mobile-app/scripts

# For Android emulator with secrets
.\build-with-secrets.ps1 -BuildType debug -InstallToEmulator

# For Windows desktop
.\build-windows.ps1 -RunAfterBuild:$false
```

The diagnostic code is now in the codebase (commit 307b747).
