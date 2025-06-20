#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# Version: v1.0.2
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

# === Help Option ===
usage() {
  echo "
  CoreLeak - Passive Recon Scanner

  Usage: ./coreleak.sh [options]

  Options:
    -t, --target TARGET      Specify target (domain/subdomain)
    -d, --dir FOLDER         Use existing output folder
    -o, --output DIR         Set output folder manually
    --phase PHASE            Run/extract only this phase (passive)
    --color                  Colorize summary output (for direct display)
    -h, --help               Show this help message
  "
  exit 0
}

# ----------- Parse Arguments -----------
TARGET=""
CUSTOM_DIR=""
OUTPUT_DIR=""
PHASE=""
COLOR_MODE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage;;
    -t|--target) TARGET="$2"; shift 2;;
    -d|--dir|--folder) CUSTOM_DIR="$2"; shift 2;;
    -o|--output) OUTPUT_DIR="$2"; shift 2;;
    --phase) PHASE="$2"; shift 2;;
    --color) COLOR_MODE=1; shift;;
    *) echo "Unknown argument: $1"; usage;;
  esac
done

# ----------- Main Output Folder -----------
if [[ -n "$CUSTOM_DIR" ]]; then
  OUTPUT_DIR="$CUSTOM_DIR"
elif [[ -z "$OUTPUT_DIR" ]]; then
  if [[ -n "$TARGET" ]]; then
    TS=$(date +%Y%m%d%H%M%S)
    SERIAL_FILE=".coreleak_serial_${TARGET}"
    SERIAL=1
    if [ -f "$SERIAL_FILE" ]; then
      SERIAL=$(( $(cat "$SERIAL_FILE") + 1 ))
    fi
    echo "$SERIAL" > "$SERIAL_FILE"
    OUTPUT_DIR="coreleak_${TARGET}_${TS}-${SERIAL}"
  else
    OUTPUT_DIR=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
  fi
fi

if [[ -z "$OUTPUT_DIR" ]]; then
  echo "[!] No output folder specified or found. Use -t or -d." >&2
  exit 1
fi
mkdir -p "$OUTPUT_DIR"

PASSIVE_LOG="$OUTPUT_DIR/passive_log.txt"
ERR_LOG="$OUTPUT_DIR/passive_error_log.txt"
: > "$PASSIVE_LOG"
: > "$ERR_LOG"

# If only phase extraction requested, skip the rest
if [[ -n "$PHASE" && "$PHASE" != "passive" ]]; then
  echo "[*] Skipping passive phase (phase flag set to $PHASE)" | tee -a "$PASSIVE_LOG"
  exit 0
fi

# ---- 1. User Input (if not passed) ----
if [[ -z "$TARGET" ]]; then
  read -rp "Enter target (domain or subdomain): " TARGET
  if [ -z "$TARGET" ]; then
    echo "[!] No input provided. Exiting." | tee -a "$PASSIVE_LOG"
    exit 1
  fi
fi

# ---- Tool Check ----
REQUIRED_TOOLS=(subfinder amass assetfinder subjs gau waybackurls arjun)
declare -A TOOL_URLS
TOOL_URLS[subfinder]="https://github.com/projectdiscovery/subfinder#installation"
TOOL_URLS[amass]="https://github.com/owasp-amass/amass"
TOOL_URLS[assetfinder]="https://github.com/tomnomnom/assetfinder"
TOOL_URLS[subjs]="https://github.com/lc/subjs"
TOOL_URLS[gau]="https://github.com/lc/gau"
TOOL_URLS[waybackurls]="https://github.com/tomnomnom/waybackurls"
TOOL_URLS[arjun]="https://github.com/s0md3v/Arjun"

TOOL_MISSING=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool is not installed! Please run install.sh or install manually: ${TOOL_URLS[$tool]}" | tee -a "$PASSIVE_LOG"
    TOOL_MISSING=1
  fi
done
if [ "$TOOL_MISSING" -eq 1 ]; then
  echo "[✗] One or more tools are missing. Exiting." | tee -a "$PASSIVE_LOG"
  exit 1
fi

echo "====================================="
echo "     CoreLeak: Passive Recon         "
echo "====================================="

# ---- Detect mode: domain vs subdomain ----
DOTS=$(echo "$TARGET" | tr -cd '.' | wc -c)
MODE="subdomain"
[ "$DOTS" -le 2 ] && MODE="domain"
echo "[*] Detected mode: $MODE" | tee -a "$PASSIVE_LOG"

# ---- 2. Subdomain Enumeration ----
if [ "$MODE" = "domain" ]; then
  echo "[*] Running subfinder, amass, assetfinder..." | tee -a "$PASSIVE_LOG"
  subfinder -d "$TARGET" -silent > "$OUTPUT_DIR/subs_subfinder.txt" 2>>"$ERR_LOG" || true
  amass enum -passive -d "$TARGET" > "$OUTPUT_DIR/subs_amass.txt" 2>>"$ERR_LOG" || true
  assetfinder --subs-only "$TARGET" > "$OUTPUT_DIR/subs_assetfinder.txt" 2>>"$ERR_LOG" || true
  cat "$OUTPUT_DIR"/subs_*.txt | sort -u > "$OUTPUT_DIR/subs.txt"
else
  echo "$TARGET" > "$OUTPUT_DIR/subs.txt"
fi

# ---- 3. JS URLs Collection ----
echo "[*] Collecting JS file URLs using subjs..." | tee -a "$PASSIVE_LOG"
cat "$OUTPUT_DIR/subs.txt" | subjs > "$OUTPUT_DIR/js_urls.txt" 2>>"$ERR_LOG" || true

# ---- 4. Archived URLs ----
echo "[*] Collecting URLs using gau and waybackurls..." | tee -a "$PASSIVE_LOG"
gau < "$OUTPUT_DIR/subs.txt" > "$OUTPUT_DIR/urls_gau.txt" 2>>"$ERR_LOG" || true
if command -v waybackurls &>/dev/null; then
  cat "$OUTPUT_DIR/subs.txt" | waybackurls > "$OUTPUT_DIR/urls_wayback.txt" 2>>"$ERR_LOG" || true
  cat "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_wayback.txt" | sort -u > "$OUTPUT_DIR/urls_raw.txt"
else
  cp "$OUTPUT_DIR/urls_gau.txt" "$OUTPUT_DIR/urls_raw.txt"
fi

# ---- 5. Filtering ----
grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' "$OUTPUT_DIR/urls_raw.txt" | sort -u > "$OUTPUT_DIR/urls_filtered.txt"

# ---- 6. Arjun Param Discovery ----
echo "[*] Running Arjun..." | tee -a "$PASSIVE_LOG"
python3 -m arjun -i "$OUTPUT_DIR/urls_filtered.txt" -oT "$OUTPUT_DIR/arjun_params.txt" 2>>"$ERR_LOG" || true

# ---- 7. Sensitive Keyword Matching ----
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

grep -iFf "$OUTPUT_DIR/sensitive_words.txt" "$OUTPUT_DIR/urls_filtered.txt" | sort -u > "$OUTPUT_DIR/flagged.txt" 2>>"$ERR_LOG" || true

# ---- 8. Results/Warnings & Summary ----
FOUND=0
[[ -s "$OUTPUT_DIR/subs.txt" ]] && FOUND=1
[[ -s "$OUTPUT_DIR/js_urls.txt" ]] && FOUND=1
[[ -s "$OUTPUT_DIR/urls_filtered.txt" ]] && FOUND=1
[[ -s "$OUTPUT_DIR/flagged.txt" ]] && FOUND=1

# === Summary Header ===
SUM_SUBS=$(wc -l < "$OUTPUT_DIR/subs.txt" 2>/dev/null)
SUM_JS=$(wc -l < "$OUTPUT_DIR/js_urls.txt" 2>/dev/null)
SUM_URLS=$(wc -l < "$OUTPUT_DIR/urls_filtered.txt" 2>/dev/null)
SUM_SENS=$(wc -l < "$OUTPUT_DIR/flagged.txt" 2>/dev/null)
[ $COLOR_MODE -eq 1 ] && CYAN="\033[1;36m" || CYAN=""
[ $COLOR_MODE -eq 1 ] && YELLOW="\033[1;33m" || YELLOW=""
[ $COLOR_MODE -eq 1 ] && RED="\033[1;31m" || RED=""
[ $COLOR_MODE -eq 1 ] && RESET="\033[0m" || RESET=""

printf "${CYAN}------ SUMMARY ------\n"
printf "   - Subdomains found: ${YELLOW}${SUM_SUBS}${RESET}\n"
printf "   - JS URLs: ${YELLOW}${SUM_JS}${RESET}\n"
printf "   - Filtered URLs: ${YELLOW}${SUM_URLS}${RESET}\n"
printf "   - Sensitive keywords matched: ${RED}${SUM_SENS}${RESET}\n"
printf "---------------------${RESET}\n"

# ---- If No Data at all ----
if [ $FOUND -eq 0 ]; then
  echo -e "${RED}[!] No results found for this phase. Check your input/tools.${RESET}" | tee -a "$PASSIVE_LOG"
fi

echo "=====================================" | tee -a "$PASSIVE_LOG"
echo "[✓] Passive recon complete for: $TARGET" | tee -a "$PASSIVE_LOG"
