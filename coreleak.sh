#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Display help message
usage() {
  cat <<EOF
Usage: ${0##*/} [options]
  -h, --help    Show this help message and exit
EOF
}

# Process help flag
while [[ "${1:-}" =~ ^(-h|--help)$ ]]; do
  usage
  exit 0
done

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "====================================="
echo " 🔍 CoreLeak: Passive Recon Scanner 🔐"
echo "====================================="

# ---- Tool Check ----
REQUIRED_TOOLS=(
  subfinder
  amass
  assetfinder
  subjs
  gau
  waybackurls
  arjun
)
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool is not installed! Please run install.sh before running this script."
    exit 1
  fi
done

# ---- 1. User Input ----
read -rp "Enter target (domain or subdomain): " TARGET
if [ -z "$TARGET" ]; then
  echo "[!] No input provided. Exiting."
  exit 1
fi

# Detect mode: domain vs subdomain
DOTS=$(echo "$TARGET" | tr -cd '.' | wc -c)
MODE="subdomain"
[ "$DOTS" -le 2 ] && MODE="domain"
echo "[*] Detected mode: $MODE"

# ---- 2. Setup output folder ----
TS=$(date +%Y%m%d_%H%M%S)
SERIAL_FILE=".coreleak_serial"
SERIAL=1
if [ -f "$SERIAL_FILE" ]; then
  SERIAL=$(( $(cat "$SERIAL_FILE") + 1 ))
fi
echo "$SERIAL" > "$SERIAL_FILE"
OUTPUT_DIR="coreleak_${TARGET}${TS}${SERIAL}"
mkdir -p "$OUTPUT_DIR"
echo "[*] Output folder: $OUTPUT_DIR"

# ---- 3. GitDorker / Google Dork ----
GITDORKER_RESULTS="$OUTPUT_DIR/gitdorker_results.txt"
GOOGLEDORK_RESULTS="$OUTPUT_DIR/googledork_results.txt"

run_git_google_dork() {
  echo "[*] Running GitDorker..."
  touch "$GITDORKER_RESULTS"

  echo "[*] Running Google Dork..."
  touch "$GOOGLEDORK_RESULTS"
}

if [ "$MODE" = "subdomain" ]; then
  echo "[*] Subdomain detected. Running GitDorker/Google Dork automatically..."
  run_git_google_dork
else
  read -rp "[?] Run GitDorker/Google Dork leaks search? [y/n]: " RUNLEAKS
  if [[ "$RUNLEAKS" == "y" ]]; then
    run_git_google_dork
  fi
fi

# ---- 4. Subdomain Enumeration (if root domain) ----
if [ "$MODE" = "domain" ]; then
  echo "[*] Running subfinder..."
  subfinder -d "$TARGET" -silent > "$OUTPUT_DIR/subs_subfinder.txt" || echo "[!] subfinder failed"

  echo "[*] Running amass..."
  if [ -f ~/resolvers.txt ] && [ -s ~/resolvers.txt ]; then
    amass enum -passive -d "$TARGET" -rf ~/resolvers.txt > "$OUTPUT_DIR/subs_amass.txt"
  else
    echo "[!] resolvers.txt missing or empty. Running without it."
    amass enum -passive -d "$TARGET" > "$OUTPUT_DIR/subs_amass.txt"
  fi

  echo "[*] Running assetfinder..."
  assetfinder --subs-only "$TARGET" > "$OUTPUT_DIR/subs_assetfinder.txt" || echo "[!] assetfinder failed"

  echo "[*] Merging subdomains..."
  cat "$OUTPUT_DIR"/subs_*.txt | sort -u > "$OUTPUT_DIR/subs.txt"
else
  echo "$TARGET" > "$OUTPUT_DIR/subs.txt"
fi

# ---- 5. JS URLs Collection ----
echo "[*] Collecting JS file URLs using subjs..."
cat "$OUTPUT_DIR/subs.txt" | subjs > "$OUTPUT_DIR/js_urls.txt" || echo "[!] subjs failed"

# ---- 6. Archived URLs ----
echo "[*] Collecting URLs using gau..."
gau < "$OUTPUT_DIR/subs.txt" > "$OUTPUT_DIR/urls_gau.txt" || echo "[!] gau failed"

if command -v waybackurls &>/dev/null; then
  echo "[*] Collecting URLs using waybackurls..."
  cat "$OUTPUT_DIR/subs.txt" | waybackurls > "$OUTPUT_DIR/urls_wayback.txt"
  cat "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_wayback.txt" | sort -u > "$OUTPUT_DIR/urls_raw.txt"
else
  cp "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_raw.txt"
fi

# ---- 7. Optional Filtering ----
read -rp "[?] Apply strong filter to URLs (dev/internal/staging)? [y/n]: " STRONGFILTER
if [[ "$STRONGFILTER" == "y" ]]; then
  echo "[] Applying strong filter..."
  grep -vEi 'internal|staging|dev|localhost' "$OUTPUT_DIR/urls_raw.txt" \
    | grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' \
    | sort -u > "$OUTPUT_DIR/urls_filtered.txt"
else
  echo "[] No strong filter. Saving all URLs with matching extensions."
  grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' "$OUTPUT_DIR/urls_raw.txt" \
    | sort -u > "$OUTPUT_DIR/urls_filtered.txt"
fi

# ---- 8. LinkFinder on JS files ----
echo "[*] Running LinkFinder..."
> "$OUTPUT_DIR/linkfinder_output.txt"
grep -Ei '\.js$' "$OUTPUT_DIR/urls_filtered.txt" \
  | xargs -I {} -P 4 python3 LinkFinder/linkfinder.py -i {} -o cli \
  >> "$OUTPUT_DIR/linkfinder_output.txt"

# ---- 9. Arjun Param Discovery ----
echo "[*] Running Arjun..."
python3 -m arjun -i "$OUTPUT_DIR/urls_filtered.txt" -oT "$OUTPUT_DIR/arjun_params.txt" \
  || echo "[!] arjun failed"

# ---- 10. Sensitive Keyword Matching ----
cat <<EOF > "$OUTPUT_DIR/sensitive_words.txt"
access_token
admin
auth
api
client_id
client_secret
config
credentials
db
debug
email
ftp
host
jwt
key
login
logout
mysql
oauth
passwd
password
private
secret
secrettoken
session
smtp
sql
ssh
ssl
token
user
username
verify
EOF

echo "[] Searching for sensitive keywords..."
grep -iFf "$OUTPUT_DIR/sensitive_words.txt" "$OUTPUT_DIR/urls_filtered.txt" \
  | sort -u > "$OUTPUT_DIR/flagged.txt"

# ---- 11. Findings messages ----
findings_msg() {
  local FILE="$1"
  local TOOL="$2"
  if [ -s "$FILE" ]; then
    N=$(wc -l < "$FILE" | tr -d ' ')
    echo "[!] Found $N sensitive findings in $TOOL (see: $FILE)"
  else
    echo "[✓] No important findings in $TOOL."
  fi
}

findings_msg "$OUTPUT_DIR/flagged.txt" "Sensitive Keyword Search"
findings_msg "$GITDORKER_RESULTS" "GitDorker"
findings_msg "$GOOGLEDORK_RESULTS" "Google Dork"

# ---- 12. Summary ----
echo -e "\n[+] Summary:"
echo "   - Subdomains found: $(wc -l < "$OUTPUT_DIR/subs.txt" 2>/dev/null)"
echo "   - JS URLs: $(wc -l < "$OUTPUT_DIR/js_urls.txt" 2>/dev/null)"
echo "   - Filtered URLs: $(wc -l < "$OUTPUT_DIR/urls_filtered.txt" 2>/dev/null)"
echo "   - Sensitive keywords matched: $(wc -l < "$OUTPUT_DIR/flagged.txt" 2>/dev/null)"
echo "✅ Passive Recon Completed."
echo "📁 All output saved in: $OUTPUT_DIR/"
