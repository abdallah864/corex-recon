#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# Version: v1.0.1
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

# === Help Function ===
usage() {
  cat <<EOF
CoreActive - Automated Active Recon

Usage: ./coreactive.sh [options]

Options:
  -h, --help               Show this help message
  -p, --passive-folder DIR Specify existing passive scan folder (default: latest coreleak_*)
  -d, --dir DIR            Alias for --passive-folder
  -t, --target TARGET      Run on specific target (auto-detect latest coreleak_TARGET)
  -c, --config FILE        Path to config file (default: api_config.yaml)
  --phase PHASE            Only run phase (active/all)
  -o, --output PATH        Custom output folder for active results

Description:
  Uses results from passive recon to run active scanning:
    - HTTP probing (httpx)
    - Port & vulnerability scan (nmap)
    - Vulnerability templates (nuclei)
    - Pattern matching (gf)
    - Sensitive keyword scan

Requirements: httpx, nuclei, gf, nmap

EOF
  exit 0
}

# ---- Parse Arguments ----
PASSIVE_FOLDER=""
TARGET=""
CONFIG_FILE="api_config.yaml"
PHASE="all"
OUTPUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage ;;
    -p|--passive-folder|-d|--dir|--folder) PASSIVE_FOLDER="$2"; shift 2 ;;
    -t|--target) TARGET="$2"; shift 2 ;;
    -c|--config) CONFIG_FILE="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- Determine Passive Folder (Manual/Auto) ----
if [[ -z "$PASSIVE_FOLDER" ]]; then
  if [[ -n "$TARGET" ]]; then
    PASSIVE_FOLDER=$(ls -dt coreleak_"$TARGET"_* 2>/dev/null | head -n1)
  else
    # Select latest coreleak_*
    LATEST=$(ls -dt coreleak_* 2>/dev/null | head -n1)
    if [[ -z "$LATEST" ]]; then
      echo "[!] No previous passive folder found. Available folders:"
      ls -d coreleak_* 2>/dev/null || echo "[none]"
      read -rp "[?] Enter target (domain/subdomain): " TARGET
      [ -z "$TARGET" ] && echo "[!] No target. Exiting." && exit 1
      bash coreleak.sh "$TARGET"
      PASSIVE_FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n1)
    else
      PASSIVE_FOLDER="$LATEST"
    fi
  fi
fi

if [[ -z "$PASSIVE_FOLDER" || ! -d "$PASSIVE_FOLDER" ]]; then
  echo "[!] Passive folder not found. Exiting."
  exit 1
fi

ACTIVE="${OUTPUT_DIR:-$PASSIVE_FOLDER/active}"
mkdir -p "$ACTIVE"

# ---- Load Config ----
NUCLEI_API_KEY=""
if [[ -f "$CONFIG_FILE" ]]; then
  NUCLEI_API_KEY=$(grep -A1 '^nuclei:' "$CONFIG_FILE" | grep 'api_key:' | awk '{print $2}')
fi

# ---- Initialization ----
ACTIVE_LOG="active_log.txt"
ACTIVE_ERR="active_error_log.txt"
: > "$ACTIVE_LOG"
: > "$ACTIVE_ERR"

# ---- Quick Summary Header ----
count_file() { [ -f "$1" ] && wc -l < "$1" || echo "0"; }
n200=0; n403=0; nlive=0; nhigh=0
if [[ -f "$PASSIVE_FOLDER/active/live_urls.txt" ]]; then
  nlive=$(count_file "$PASSIVE_FOLDER/active/live_urls.txt")
fi
if [[ -f "$PASSIVE_FOLDER/active/http_200.txt" ]]; then
  n200=$(count_file "$PASSIVE_FOLDER/active/http_200.txt")
fi
if [[ -f "$PASSIVE_FOLDER/active/http_403.txt" ]]; then
  n403=$(count_file "$PASSIVE_FOLDER/active/http_403.txt")
fi
# Display summary header
echo -e "\033[1;36m========== Recon Active Summary ==========\033[0m"
echo "  Live Endpoints : $nlive"
echo "  HTTP 200 URLs  : $n200"
echo "  HTTP 403 URLs  : $n403"
echo "=========================================="

echo "========================================" | tee -a "$ACTIVE_LOG"
echo "    CoreActive: Automated Active Recon  " | tee -a "$ACTIVE_LOG"
echo "========================================" | tee -a "$ACTIVE_LOG"
echo "[*] Passive folder: $PASSIVE_FOLDER" | tee -a "$ACTIVE_LOG"
echo "[*] Active output: $ACTIVE" | tee -a "$ACTIVE_LOG"
echo "[*] Config file: $CONFIG_FILE" | tee -a "$ACTIVE_LOG"
echo "[*] Nuclei API Key: ${NUCLEI_API_KEY:-}" | tee -a "$ACTIVE_LOG"

# ---- Tool Check ----
REQUIRED_TOOLS=(httpx nuclei gf nmap)
declare -A TOOL_URLS
TOOL_URLS[httpx]="https://github.com/projectdiscovery/httpx#installation"
TOOL_URLS[nuclei]="https://github.com/projectdiscovery/nuclei#installation"
TOOL_URLS[gf]="https://github.com/tomnomnom/gf"
TOOL_URLS[nmap]="https://nmap.org/book/inst-windows.html"

MISSING=0
for t in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$t" &>/dev/null; then
    echo "[!] $t not installed. Install: ${TOOL_URLS[$t]}" | tee -a "$ACTIVE_LOG"
    MISSING=1
  fi
done
if (( MISSING )); then
  echo "[✗] Missing tools. Exiting." | tee -a "$ACTIVE_LOG"
  exit 1
fi

# ---- Only run specific phase if --phase used ----
if [[ "$PHASE" != "all" && "$PHASE" != "active" ]]; then
  echo "[!] This script supports only --phase active (default: all)"
  exit 1
fi

# ---- 1: HTTP Probing ----
if [[ -f "$PASSIVE_FOLDER/urls_filtered.txt" ]]; then
  echo "[*] Running httpx..." | tee -a "$ACTIVE_LOG"
  httpx -silent -status-code -title -tech-detect -ip -cname -location \
    -l "$PASSIVE_FOLDER/urls_filtered.txt" \
    > "$ACTIVE/live_urls.txt" 2>>"$ACTIVE_ERR" ||  echo "[!] httpx failed" | tee -a "$ACTIVE_LOG"

  awk '$2==200' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_200.txt"
  awk '$2==403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_403.txt"
  awk '$2!=200 && $2!=403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_other.txt"

  # Quick highlight (color if terminal supports)
  if [[ -t 1 ]]; then
    echo -e "\033[1;32m[✓] HTTPx done.\033[0m 200:$(count_file "$ACTIVE/http_200.txt"), 403:$(count_file "$ACTIVE/http_403.txt"), other:$(count_file "$ACTIVE/http_other.txt")"
  else
    echo "[*] httpx done. 200:$(count_file "$ACTIVE/http_200.txt"), 403:$(count_file "$ACTIVE/http_403.txt"), other:$(count_file "$ACTIVE/http_other.txt")"
  fi
else
  echo "[!] urls_filtered.txt not found. Skipping httpx." | tee -a "$ACTIVE_LOG"
fi

# ---- 2: Nmap Scan ----
if [[ -s "$ACTIVE/http_200.txt" ]]; then
  echo "[*] Extracting IPs for nmap..." | tee -a "$ACTIVE_LOG"
  awk '{print $5}' "$ACTIVE/http_200.txt" | sort -u > "$ACTIVE/live_ips.txt"
  if [[ -s "$ACTIVE/live_ips.txt" ]]; then
    echo "[*] Running nmap..." | tee -a "$ACTIVE_LOG"
    nmap -T4 -Pn -sV -iL "$ACTIVE/live_ips.txt" -oN "$ACTIVE/nmap_scan.txt" 2>>"$ACTIVE_ERR" ||  echo "[!] nmap failed" | tee -a "$ACTIVE_LOG"
  else
    echo -e "\033[1;33m[!] No live IPs. Skipping nmap.\033[0m" | tee -a "$ACTIVE_LOG"
  fi
else
  echo -e "\033[1;33m[!] No HTTP 200. Skipping nmap.\033[0m" | tee -a "$ACTIVE_LOG"
fi

# ---- 3: Nuclei Scan ----
if [[ -s "$ACTIVE/http_200.txt" ]]; then
  echo "[*] Running nuclei..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200.txt" > "$ACTIVE/http_200_urls.txt"
  if [[ -n "$NUCLEI_API_KEY" ]]; then
    nuclei -api-key "$NUCLEI_API_KEY" -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt" 2>>"$ACTIVE_ERR" ||  echo "[!] nuclei failed" | tee -a "$ACTIVE_LOG"
  else
    nuclei -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt" 2>>"$ACTIVE_ERR" ||  echo "[!] nuclei failed" | tee -a "$ACTIVE_LOG"
  fi
else
  echo "[!] No HTTP 200. Skipping nuclei." | tee -a "$ACTIVE_LOG"
fi

# ---- 4: GF Patterns ----
if [[ -s "$ACTIVE/http_200.txt" ]]; then
  echo "[*] Running gf patterns..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200_urls.txt" | while read url; do
    for pattern in xss ssrf lfi; do
      gf "$pattern" <<< "$url" >> "$ACTIVE/gf_${pattern}_hits.txt" 2>>"$ACTIVE_ERR"
    done
  done || echo "[!] gf patterns failed" | tee -a "$ACTIVE_LOG"
else
  echo "[!] No HTTP 200. Skipping gf patterns." | tee -a "$ACTIVE_LOG"
fi

# ---- 5: HTTP 403 Handling ----
if [[ -s "$ACTIVE/http_403.txt" ]]; then
  echo -e "\033[1;31m[!] HTTP 403 found. See: $ACTIVE/http_403.txt\033[0m" | tee -a "$ACTIVE_LOG"
  echo "[!] Consider manual bypass." | tee -a "$ACTIVE_LOG"
else
  echo "[*] No 403 responses." | tee -a "$ACTIVE_LOG"
fi

# ---- 6: Sensitive Keyword Scan ----
if [[ -f "$PASSIVE_FOLDER/sensitive_words.txt" && -s "$ACTIVE/http_200.txt" ]]; then
  echo "[*] Scanning for sensitive keywords..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200.txt" | grep -iFf "$PASSIVE_FOLDER/sensitive_words.txt" > "$ACTIVE/sensitive_matches.txt" 2>>"$ACTIVE_ERR" ||  echo "[!] keyword scan failed" | tee -a "$ACTIVE_LOG"
else
  echo "[!] Missing sensitive_words.txt or HTTP 200 results. Skipping." | tee -a "$ACTIVE_LOG"
fi

# ---- Final: Warn if no results at all ----
noresults=true
for f in "$ACTIVE/live_urls.txt" "$ACTIVE/http_200.txt" "$ACTIVE/http_403.txt" "$ACTIVE/nmap_scan.txt" "$ACTIVE/nuclei_report.txt"; do
  [[ -s "$f" ]] && noresults=false
done
if $noresults; then
  echo -e "\033[1;31m[!] No results found for this phase. Check your input or passive stage output.\033[0m" | tee -a "$ACTIVE_LOG"
fi

echo "========================================" | tee -a "$ACTIVE_LOG"
echo -e "\033[1;32m[✓] Active Recon Finished.\033[0m" | tee -a "$ACTIVE_LOG"
echo "[✓] Output in: $ACTIVE" | tee -a "$ACTIVE_LOG"

# ---- Ask to continue or exit ----
echo
read -rp "[?] Continue to Exploitation phase (coreexploit.sh)? [y/n]: " nextstep
if [[ "$nextstep" =~ ^[Yy]$ ]]; then
  bash coreexploit.sh -p "$PASSIVE_FOLDER"
fi
