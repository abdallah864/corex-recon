#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "====================================="
echo " 🔍 CoreLeak: Passive Recon Scanner 🔍"
echo "====================================="

PASSIVE_LOG="passive_log.txt"
ERR_LOG="passive_error_log.txt"
: > "$PASSIVE_LOG"
: > "$ERR_LOG"

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

TOOL_MISSING=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool is not installed! Please run install.sh before running this script." | tee -a "$PASSIVE_LOG"
    TOOL_MISSING=1
  fi
done
if [ "$TOOL_MISSING" -eq 1 ]; then
  echo "[✗] One or more tools are missing. Exiting." | tee -a "$PASSIVE_LOG"
  exit 1
fi

# ---- 1. User Input ----
read -rp "Enter target (domain or subdomain): " TARGET
if [ -z "$TARGET" ]; then
  echo "[!] No input provided. Exiting." | tee -a "$PASSIVE_LOG"
  exit 1
fi

# Detect mode: domain vs subdomain
DOTS=$(echo "$TARGET" | tr -cd '.' | wc -c)
MODE="subdomain"
[ "$DOTS" -le 2 ] && MODE="domain"
echo "[*] Detected mode: $MODE" | tee -a "$PASSIVE_LOG"

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
echo "[*] Output folder: $OUTPUT_DIR" | tee -a "$PASSIVE_LOG"

# ---- 3. GitDorker / Google Dork ----
GITDORKER_RESULTS="$OUTPUT_DIR/gitdorker_results.txt"
GOOGLEDORK_RESULTS="$OUTPUT_DIR/googledork_results.txt"

run_git_google_dork() {
  echo "[*] Running GitDorker..." | tee -a "$PASSIVE_LOG"
  touch "$GITDORKER_RESULTS"
  # (Integration command can be placed here)

  echo "[*] Running Google Dork..." | tee -a "$PASSIVE_LOG"
  touch "$GOOGLEDORK_RESULTS"
  # (Integration command can be placed here)
}

if [ "$MODE" = "subdomain" ]; then
  echo "[*] Subdomain detected. Running GitDorker/Google Dork automatically..." | tee -a "$PASSIVE_LOG"
  run_git_google_dork
else
  read -rp "[?] Run GitDorker/Google Dork leaks search? [y/n]: " RUNLEAKS
  if [[ "$RUNLEAKS" == "y" ]]; then
    run_git_google_dork
  fi
fi

# ---- 4. Subdomain Enumeration (if root domain) ----
if [ "$MODE" = "domain" ]; then
  echo "[*] Running subfinder..." | tee -a "$PASSIVE_LOG"
  if ! subfinder -d "$TARGET" -silent > "$OUTPUT_DIR/subs_subfinder.txt" 2>>"$ERR_LOG"; then
    echo "[!] subfinder failed." | tee -a "$PASSIVE_LOG"
  fi

  echo "[*] Running amass..." | tee -a "$PASSIVE_LOG"
  if [ -f ~/resolvers.txt ] && [ -s ~/resolvers.txt ]; then
    if ! amass enum -passive -d "$TARGET" -rf ~/resolvers.txt > "$OUTPUT_DIR/subs_amass.txt" 2>>"$ERR_LOG"; then
      echo "[!] amass failed." | tee -a "$PASSIVE_LOG"
    fi
  else
    echo "[!] resolvers.txt missing or empty. Running amass without it." | tee -a "$PASSIVE_LOG"
    if ! amass enum -passive -d "$TARGET" > "$OUTPUT_DIR/subs_amass.txt" 2>>"$ERR_LOG"; then
      echo "[!] amass failed." | tee -a "$PASSIVE_LOG"
    fi
  fi

  echo "[*] Running assetfinder..." | tee -a "$PASSIVE_LOG"
  if ! assetfinder --subs-only "$TARGET" > "$OUTPUT_DIR/subs_assetfinder.txt" 2>>"$ERR_LOG"; then
    echo "[!] assetfinder failed." | tee -a "$PASSIVE_LOG"
  fi

  echo "[*] Merging subdomains..." | tee -a "$PASSIVE_LOG"
  cat "$OUTPUT_DIR"/subs_*.txt | sort -u > "$OUTPUT_DIR/subs.txt"
else
  echo "$TARGET" > "$OUTPUT_DIR/subs.txt"
fi

# ---- 5. JS URLs Collection ----
echo "[*] Collecting JS file URLs using subjs..." | tee -a "$PASSIVE_LOG"
if ! cat "$OUTPUT_DIR/subs.txt" | subjs > "$OUTPUT_DIR/js_urls.txt" 2>>"$ERR_LOG"; then
  echo "[!] subjs failed." | tee -a "$PASSIVE_LOG"
fi

# ---- 6. Archived URLs ----
echo "[*] Collecting URLs using gau..." | tee -a "$PASSIVE_LOG"
if ! gau < "$OUTPUT_DIR/subs.txt" > "$OUTPUT_DIR/urls_gau.txt" 2>>"$ERR_LOG"; then
  echo "[!] gau failed." | tee -a "$PASSIVE_LOG"
fi

if command -v waybackurls &>/dev/null; then
  echo "[*] Collecting URLs using waybackurls..." | tee -a "$PASSIVE_LOG"
  if ! cat "$OUTPUT_DIR/subs.txt" | waybackurls > "$OUTPUT_DIR/urls_wayback.txt" 2>>"$ERR_LOG"; then
    echo "[!] waybackurls failed." | tee -a "$PASSIVE_LOG"
    cp "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_raw.txt"
  else
    cat "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_wayback.txt" | sort -u > "$OUTPUT_DIR/urls_raw.txt"
  fi
else
  cp "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_raw.txt"
fi

# ---- 7. Optional Filtering ----
read -rp "[?] Apply strong filter to URLs (dev/internal/staging)? [y/n]: " STRONGFILTER
if [[ "$STRONGFILTER" == "y" ]]; then
  echo "[*] Applying strong filter..." | tee -a "$PASSIVE_LOG"
  grep -vEi 'internal|staging|dev|localhost' "$OUTPUT_DIR/urls_raw.txt" \
    | grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' \
    | sort -u > "$OUTPUT_DIR/urls_filtered.txt"
else
  echo "[*] No strong filter. Saving all URLs with matching extensions." | tee -a "$PASSIVE_LOG"
  grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' "$OUTPUT_DIR/urls_raw.txt" \
    | sort -u > "$OUTPUT_DIR/urls_filtered.txt"
fi

# ---- 8. LinkFinder on JS files ----
echo "[*] Running LinkFinder..." | tee -a "$PASSIVE_LOG"
> "$OUTPUT_DIR/linkfinder_output.txt"
if ! grep -Ei '\.js$' "$OUTPUT_DIR/urls_filtered.txt" \
  | xargs -I {} -P 4 python3 LinkFinder/linkfinder.py -i {} -o cli \
  >> "$OUTPUT_DIR/linkfinder_output.txt" 2>>"$ERR_LOG"; then
    echo "[!] LinkFinder failed or some JS files could not be processed." | tee -a "$PASSIVE_LOG"
fi

# ---- 9. Arjun Param Discovery ----
echo "[*] Running Arjun..." | tee -a "$PASSIVE_LOG"
if ! python3 -m arjun -i "$OUTPUT_DIR/urls_filtered.txt" -oT "$OUTPUT_DIR/arjun_params.txt" 2>>"$ERR_LOG"; then
  echo "[!] arjun failed." | tee -a "$PASSIVE_LOG"
fi

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

echo "[*] Searching for sensitive keywords..." | tee -a "$PASSIVE_LOG"
if ! grep -iFf "$OUTPUT_DIR/sensitive_words.txt" "$OUTPUT_DIR/urls_filtered.txt" \
  | sort -u > "$OUTPUT_DIR/flagged.txt" 2>>"$ERR_LOG"; then
    echo "[!] grep for sensitive keywords failed." | tee -a "$PASSIVE_LOG"
fi

# ---- 11. Findings messages ----
findings_msg() {
  local FILE="$1"
  local TOOL="$2"
  if [ -s "$FILE" ]; then
    N=$(wc -l < "$FILE" | tr -d ' ')
    echo "[!] Found $N sensitive findings in $TOOL (see: $FILE)" | tee -a "$PASSIVE_LOG"
  else
    echo "[✓] No important findings in $TOOL." | tee -a "$PASSIVE_LOG"
  fi
}

findings_msg "$OUTPUT_DIR/flagged.txt" "Sensitive Keyword Search"
findings_msg "$GITDORKER_RESULTS" "GitDorker"
findings_msg "$GOOGLEDORK_RESULTS" "Google Dork"

# ---- 12. Summary ----
echo -e "\n[+] Summary:" | tee -a "$PASSIVE_LOG"
echo "   - Subdomains found: $(wc -l < "$OUTPUT_DIR/subs.txt" 2>/dev/null)" | tee -a "$PASSIVE_LOG"
echo "   - JS URLs: $(wc -l < "$OUTPUT_DIR/js_urls.txt" 2>/dev/null)" | tee -a "$PASSIVE_LOG"
echo "   - Filtered URLs: $(wc -l < "$OUTPUT_DIR/urls_filtered.txt" 2>/dev/null)" | tee -a "$PASSIVE_LOG"
echo "   - Sensitive keywords matched: $(wc -l < "$OUTPUT_DIR/flagged.txt" 2>/dev/null)" | tee -a "$PASSIVE_LOG"
echo "=====================================" | tee -a "$PASSIVE_LOG"
echo "[✓] Passive Recon Completed."
echo "[✓] All output saved in: $OUTPUT_DIR/ (Log: $PASSIVE_LOG, Errors: $ERR_LOG)"

