#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# Version: v1.0.2
# Licensed under the MIT License. See LICENSE file for details.
# =============================================================================

# === Help Function ===
usage() {
  cat <<EOF
CoreLeak - Passive Recon Scanner

Usage: ./coreleak.sh [options]

Options:
  -h, --help               Show this help message
  -t, --target TARGET      Specify target (domain/subdomain)
  -d, --dir DIR            Use existing output folder instead of creating new
  -o, --output DIR         Alias for --dir
  --phase PHASE            Only run this phase (passive)
  --color                  Colorize summary output
EOF
  exit 0
}

# ---- Parse Arguments ----
TARGET=""
OUTPUT_DIR=""
PHASE=""
COLOR=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   usage ;;
    -t|--target) TARGET="$2"; shift 2 ;;
    -d|--dir|-o|--output) OUTPUT_DIR="$2"; shift 2 ;;
    --phase)     PHASE="$2"; shift 2 ;;
    --color)     COLOR=1; shift ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- Determine Output Folder ----
if [[ -n "$OUTPUT_DIR" ]]; then
  DIR="$OUTPUT_DIR"
elif [[ -n "$TARGET" ]]; then
  # new run for given target
  TS=$(date +%Y%m%d_%H%M%S)
  SERIAL_FILE=".coreleak_serial_${TARGET}"
  if [[ -f "$SERIAL_FILE" ]]; then
    SERIAL=$(( $(<"$SERIAL_FILE") + 1 ))
  else
    SERIAL=1
  fi
  echo "$SERIAL" >"$SERIAL_FILE"
  DIR="coreleak_${TARGET}_${TS}-${SERIAL}"
else
  # use latest existing
  DIR=$(ls -dt coreleak_* 2>/dev/null | head -n1 || true)
fi

if [[ -z "$DIR" ]]; then
  read -rp "[?] Enter target (domain/subdomain): " TARGET
  [[ -z "$TARGET" ]] && echo "[!] No target provided. Exiting." && exit 1
  TS=$(date +%Y%m%d_%H%M%S)
  SERIAL_FILE=".coreleak_serial_${TARGET}"
  if [[ -f "$SERIAL_FILE" ]]; then
    SERIAL=$(( $(<"$SERIAL_FILE") + 1 ))
  else
    SERIAL=1
  fi
  echo "$SERIAL" >"$SERIAL_FILE"
  DIR="coreleak_${TARGET}_${TS}-${SERIAL}"
fi

mkdir -p "$DIR"

# ---- Skip if wrong phase ----
if [[ -n "$PHASE" && "$PHASE" != "passive" ]]; then
  echo "[*] Skipping passive phase (phase=$PHASE)"
  exit 0
fi

# ---- Header ----
echo "========================================"
echo "    CoreLeak: Passive Recon v1.0.2      "
echo "========================================"

# ---- Tool Check ----
TOOLS=(subfinder amass assetfinder subjs gau waybackurls arjun)
declare -A REFS=(
  [subfinder]="https://github.com/projectdiscovery/subfinder#installation"
  [amass]="https://github.com/owasp-amass/amass"
  [assetfinder]="https://github.com/tomnomnom/assetfinder"
  [subjs]="https://github.com/lc/subjs"
  [gau]="https://github.com/lc/gau"
  [waybackurls]="https://github.com/tomnomnom/waybackurls"
  [arjun]="https://github.com/s0md3v/Arjun"
)
missing=0
for t in "${TOOLS[@]}"; do
  if ! command -v "$t" &>/dev/null; then
    echo "[!] $t not installed. See: ${REFS[$t]}"
    missing=1
  fi
done
(( missing )) && { echo "[✗] Missing tools. Exiting."; exit 1; }

# ---- Phase 1: Subdomain Enumeration ----
echo "[*] Running subdomain enumeration..."
if [[ "$TARGET" =~ \. ]]; then
  subfinder -d "$TARGET" -silent >"$DIR/subs_subfinder.txt" 2>/dev/null || true
  amass enum -passive -d "$TARGET"   >"$DIR/subs_amass.txt"      2>/dev/null || true
  assetfinder --subs-only "$TARGET"  >"$DIR/subs_assetfinder.txt"2>/dev/null || true
  cat "$DIR"/subs_*.txt | sort -u >"$DIR/subs.txt"
else
  echo "$TARGET" >"$DIR/subs.txt"
fi

# ---- Phase 2: JS URLs Collection ----
echo "[*] Collecting JS URLs..."
subjs <"$DIR/subs.txt" >"$DIR/js_urls.txt" 2>/dev/null || true

# ---- Phase 3: Archived URLs ----
echo "[*] Collecting archived URLs..."
gau <"$DIR/subs.txt" >"$DIR/urls_gau.txt" 2>/dev/null || true
if command -v waybackurls &>/dev/null; then
  waybackurls <"$DIR/subs.txt" >"$DIR/urls_wayback.txt" 2>/dev/null || true
  cat "$DIR"/urls_gau.txt "$DIR"/urls_wayback.txt | sort -u >"$DIR/urls_raw.txt"
else
  cp "$DIR/urls_gau.txt" "$DIR/urls_raw.txt"
fi

# ---- Phase 4: Filtering ----
echo "[*] Filtering URLs..."
grep -Ei '\.js|\.php|\.aspx|\.jsp|\.json' "$DIR/urls_raw.txt" | sort -u >"$DIR/urls_filtered.txt"

# ---- Phase 5: Arjun Param Discovery ----
echo "[*] Running Arjun..."
python3 -m arjun -i "$DIR/urls_filtered.txt" -oT "$DIR/arjun_params.txt" 2>/dev/null || true

# ---- Phase 6: Sensitive Keywords ----
echo "[*] Generating sensitive_words.txt..."
cat <<EOF >"$DIR/sensitive_words.txt"
access_token
admin
api_key
password
secret
token
login
logout
session
credentials
EOF

echo "[*] Matching sensitive keywords..."
grep -iFf "$DIR/sensitive_words.txt" "$DIR/urls_filtered.txt" | sort -u >"$DIR/flagged.txt" 2>/dev/null || true

# ---- Summary ----
echo "========================================"
echo "Summary:"
echo "  Subdomains : $(wc -l <"$DIR/subs.txt")"
echo "  JS URLs     : $(wc -l <"$DIR/js_urls.txt")"
echo "  Filtered    : $(wc -l <"$DIR/urls_filtered.txt")"
echo "  Flagged     : $(wc -l <"$DIR/flagged.txt")"
echo "========================================"
echo "[✓] Passive Recon complete: $DIR"
