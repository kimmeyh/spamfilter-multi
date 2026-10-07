#!/usr/bin/env bash
# Configure the Dovecot test IMAP server inside Ubuntu WSL (run as root).
# Called by scripts/start-test-imap-servers.ps1; safe to re-run.
#
# Test-only: one local user "tester" / "testpass" with a few seeded messages,
# STARTTLS on 143 and SSL/TLS on 993 using Ubuntu's self-signed "snakeoil"
# certificate. Dovecot's default disable_plaintext_auth=yes refuses LOGIN
# until STARTTLS succeeds -- the exact behavior the app's STARTTLS mode must
# honor (Sprint 77 F192 / SEC-8b, Harold Q3 and Q4).
set -euo pipefail

if ! command -v dovecot >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq >/dev/null
  apt-get install -y -qq dovecot-imapd >/dev/null
fi

if ! id tester >/dev/null 2>&1; then
  useradd -m -s /usr/sbin/nologin tester
fi
echo 'tester:testpass' | chpasswd

conf=/etc/dovecot/conf.d/99-spamfilter-test.conf
cat > "$conf" <<'CONF'
# spamfilter-multi test server (scripts/test-imap/dovecot-wsl-setup.sh)
listen = *
protocols = imap
mail_location = maildir:~/Maildir
ssl = yes
disable_plaintext_auth = yes
auth_mechanisms = plain login
CONF

maildir=/home/tester/Maildir
mkdir -p "$maildir/new" "$maildir/cur" "$maildir/tmp"
for i in 1 2 3; do
  f="$maildir/new/seed-$i.eml"
  if [ ! -f "$f" ]; then
    printf 'From: Test Sender %s <sender%s@example.net>\nTo: tester@spamfilter.test\nSubject: Sprint 77 test message %s\nDate: Tue, 7 Oct 2026 10:0%s:00 -0400\nMessage-ID: <seed-%s@spamfilter.test>\n\nSeeded test message %s for the custom IMAP validation.\n' "$i" "$i" "$i" "$i" "$i" "$i" > "$f"
  fi
done
chown -R tester:tester /home/tester/Maildir

# Detach fully: a daemon that keeps the caller's stdout/stderr open makes
# wsl.exe (and the PowerShell pipeline reading it) wait forever.
if pgrep -x dovecot >/dev/null 2>&1; then
  doveadm reload </dev/null >/dev/null 2>&1
else
  dovecot </dev/null >/dev/null 2>&1
fi
sleep 1
echo "dovecot $(dovecot --version) running; certificate SHA-256:"
openssl x509 -in /etc/dovecot/private/dovecot.pem -noout -fingerprint -sha256
