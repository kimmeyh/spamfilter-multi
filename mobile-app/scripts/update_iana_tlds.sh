#!/bin/bash
# Update mobile-app/lib/core/utils/iana_tlds.dart from the IANA TLD list.
#
# IANA refreshes the list periodically (new gTLDs, retirements). Re-run this
# script when adding domain validation features or when users report a real
# TLD being rejected as unknown.
#
# Usage: bash mobile-app/scripts/update_iana_tlds.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${SCRIPT_DIR}/../lib/core/utils/iana_tlds.dart"
TMP_LIST=$(mktemp)
TMP_SET=$(mktemp)

trap "rm -f $TMP_LIST $TMP_SET" EXIT

echo "[INFO] Fetching IANA TLD list..."
# --ssl-no-revoke is needed on Windows (curl + Schannel can't always reach the OCSP responder)
curl -sS --ssl-no-revoke -o "$TMP_LIST" "https://data.iana.org/TLD/tlds-alpha-by-domain.txt"

VERSION_LINE=$(head -1 "$TMP_LIST")
TLD_COUNT=$(($(wc -l < "$TMP_LIST") - 1))
echo "[INFO] $VERSION_LINE"
echo "[INFO] $TLD_COUNT TLDs"

# Build the Dart Set literal: lowercase, sorted, comma-separated quoted strings
tail -n +2 "$TMP_LIST" \
  | tr '[:upper:]' '[:lower:]' \
  | sort \
  | awk 'BEGIN{printf "{"} {printf "%s\"%s\"", (NR==1?"":","), $0} END{print "}"}' \
  > "$TMP_SET"

# Write the Dart file
{
  echo "/// Valid IANA top-level domains (TLDs)."
  echo "///"
  echo "/// Source: https://data.iana.org/TLD/tlds-alpha-by-domain.txt"
  echo "/// ${VERSION_LINE#\# }"
  echo "///"
  echo "/// Update procedure: re-run scripts/update_iana_tlds.sh and commit."
  echo "/// All TLDs stored lowercase. Lookup is O(1) via Set."
  echo "library;"
  echo ""
  echo "/// IANA-registered TLDs (lowercase). Used by DomainValidation to reject"
  echo "/// invalid TLDs like 'com444' or 'whatevericanthinkof'."
  echo -n "const Set<String> kIanaTlds = "
  cat "$TMP_SET"
  echo ";"
} > "$OUTPUT_FILE"

echo "[OK] Wrote $OUTPUT_FILE"
echo "[INFO] Run 'flutter analyze' and 'flutter test test/unit/utils/domain_validation_test.dart' to verify."
