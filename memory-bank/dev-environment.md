# Developer environment

Set up a local Python virtual environment to isolate dependencies.

## Create venv (once)

```powershell
python -m venv .venv
```

## Activate venv

- Windows PowerShell
```powershell
./.venv/Scripts/Activate.ps1
```

- Windows cmd
```cmd
.venv\Scripts\activate.bat
```

- Linux/macOS bash/zsh
```bash
source .venv/bin/activate
```

## Deactivate venv

```bash
deactivate
```

After activation, install dependencies from `requirements.txt`:

```bash
pip install -r requirements.txt
```

## Windows Security & Antivirus Considerations

### Norton Antivirus 360 - Email Protection & TLS Interception

If developing/testing Flutter apps on Windows with Norton Antivirus 360 installed, be aware:

- **TLS Interception**: Norton's "Email Protection" feature performs man-in-the-middle inspection of all encrypted email (IMAP/SMTP/POP3) traffic
- **Android Emulator Impact**: The emulator's trust store does not include Norton's custom root CA, causing IMAP connections to fail with "TLS certificate validation failed"
- **Symptom**: App scan fails with error message: `Scan failed: ConnectionException: TLS certificate validation failed`

**Resolution**: Disable Norton's Email Protection
1. Open **Norton 360**
2. Navigate to **Settings > Security > Advanced > Intrusion Prevention** (or **Firewall > Advanced**)
3. Disable **"Email Protection"** or **"SSL Scanning"**
   - ⚠️ **Important**: Safe Web exclusions are NOT effective; the entire Email Protection module must be disabled

**To verify the fix** (Windows PowerShell):
```powershell
python -c "import socket, ssl; c=ssl.create_default_context(); s=socket.create_connection(('imap.aol.com',993),timeout=10); t=c.wrap_socket(s, server_hostname='imap.aol.com'); print('Issuer:', dict(x[0] for x in t.getpeercert()['issuer'])); t.close()"
```
- ✅ **Expected**: `Issuer: {'organizationName': 'DigiCert Inc', ...}` (NOT Norton)
- ❌ **If still Norton**: Email Protection is still active

**For physical Android devices**: Norton's root CA is pre-installed on phones, so no changes needed.

**See also**: [mobile-app/README.md § Troubleshooting](../mobile-app/README.md#troubleshooting) and [mobile-app/NEW_DEVELOPER_SETUP.md § Common Fixes](../mobile-app/NEW_DEVELOPER_SETUP.md#common-fixes)