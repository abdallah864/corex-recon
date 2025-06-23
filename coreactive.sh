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
CoreActive - Automated Active Recon

Usage: ./coreactive.sh [options]

Options:
  -h, --help               Show this help message
  -p, --passive-folder DIR Specify existing passive recon folder (default: latest coreleak_*)
  -d, --dir DIR            Alias for --passive-folder
  -t, --target TARGET      Run on specific target (auto-detect latest coreleak_TARGET)
  -c, --config FILE        Path to config file (default: api_config.yaml)
  --phase PHASE            Only run phase (active/all)
  -o, --output PATH        Custom output folder for active results

Description:
  Uses results from passive recon to run active scanning:
    1) HTTP probing (httpx)
    2) Port & vulnerability scan (nmap)
    3) Vulnerability templates (nuclei)
    4) Pattern matching (gf)
    5) Sensitive keyword scan

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
    -h|--help)                 usage ;;
    -p|--passive-folder|-d)    PASSIVE_FOLDER="$2"; shift 2 ;;
    -t|--target)               TARGET="$2"; shift 2 ;;
    -c|--config)               CONFIG_FILE="$2"; shift 2 ;;
    --phase)                   PHASE="$2"; shift 2 ;;
    -o|--output)               OUTPUT_DIR="$2"; shift 2 ;;
    *)                          echo "Unknown option: $1" >&2; usage ;;
  esac
done

# ---- Determine passive folder or target ----
if [[ -n "$TARGET" && -z "$PASSIVE_FOLDER" ]]; then
  PASSIVE_FOLDER=$(ls -dt coreleak_"$TARGET"_* 2>/dev/null | head -n1)
fi
if [[ -z "$PASSIVE_FOLDER" ]]; then
  PASSIVE_FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n1)
fi
if [[ -z "$PASSIVE_FOLDER" ]]; then
  read -rp "[?] Enter target (domain/subdomain): " TARGET
  [[ -z "$TARGET" ]] && echo "[!] No target provided. Exiting." && exit 1
  bash coreleak.sh -t "$TARGET"
  PASSIVE_FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n1)
fi
[[ ! -d "$PASSIVE_FOLDER" ]] && echo "[!] Passive folder '$PASSIVE_FOLDER' not found. Exiting." && exit 1

ACTIVE="${OUTPUT_DIR:-$PASSIVE_FOLDER/active}"
mkdir -p "$ACTIVE"

# ---- Load API keys from config ----
NUCLEI_API_KEY=""
SHODAN_API_KEY=""
if [[ -f "$CONFIG_FILE" ]]; then
  NUCLEI_API_KEY=$(grep -A1 '^nuclei:' "$CONFIG_FILE" | grep 'api_key:' | awk '{print $2}')
  SHODAN_API_KEY=$(grep -A1 '^shodan:'  "$CONFIG_FILE" | grep 'api_key:' | awk '{print $2}')
fi

# ---- Initialize logs ----
ACTIVE_LOG="$ACTIVE/active_log.txt"
ACTIVE_ERR="$ACTIVE/active_error_log.txt"
: >"$ACTIVE_LOG"
: >"$ACTIVE_ERR"

# ---- Header ----
echo "========================================" | tee -a "$ACTIVE_LOG"
echo "    CoreActive: Automated Active Recon  " | tee -a "$ACTIVE_LOG"
echo "========================================" | tee -a "$ACTIVE_LOG"

# ---- Check required tools ----
REQUIRED=(httpx nuclei gf nmap)
declare -A URLS=(
  [httpx]="https://github.com/projectdiscovery/httpx#installation"
  [nuclei]="https://github.com/projectdiscovery/nuclei#installation"
  [gf]="https://github.com/tomnomnom/gf"
  [nmap]="https://nmap.org/book/inst-windows.html"
)
missing=0
for tool in "${REQUIRED[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool not installed. Install: ${URLS[$tool]}" | tee -a "$ACTIVE_LOG"
    missing=1
  fi
done
(( missing )) && echo "[✗] Missing tools. Exiting." | tee -a "$ACTIVE_LOG" && exit 1

# ---- Validate phase ----
[[ "$PHASE" != "all" && "$PHASE" != "active" ]] && {
  echo "[!] Unsupported phase '$PHASE'. Use 'active' or 'all'." >&2
  exit 1
}

# ---- 1) HTTP Probing ----
echo "----------------------------------------" | tee -a "$ACTIVE_LOG"
echo "[*] Stage: HTTP Probing"             | tee -a "$ACTIVE_LOG"
if [[ -f "$PASSIVE_FOLDER/urls_filtered.txt" ]]; then
  httpx -silent -status-code -title -tech-detect -ip -cname -location \
    -l "$PASSIVE_FOLDER/urls_filtered.txt" \
    >"$ACTIVE/live_urls.txt" 2>>"$ACTIVE_ERR"
else
  echo "[!] urls_filtered.txt missing. Skipping HTTP probing." | tee -a "$ACTIVE_LOG"
fi

# ---- 2) Nmap Scan ----
echo "----------------------------------------" | tee -a "$ACTIVE_LOG"
echo "[*] Stage: Nmap Scan"               | tee -a "$ACTIVE_LOG"
if [[ -s "$ACTIVE/live_urls.txt" ]]; then
  awk '{print $5}' "$ACTIVE/live_urls.txt" | sort -u >"$ACTIVE/live_ips.txt"
  [[ -s "$ACTIVE/live_ips.txt" ]] && \
    nmap -T4 -Pn -sV -iL "$ACTIVE/live_ips.txt" -oN "$ACTIVE/nmap_scan.txt" 2>>"$ACTIVE_ERR"
else
  echo "[!] No live URLs. Skipping Nmap." | tee -a "$ACTIVE_LOG"
fi

# ---- 3) Nuclei Scan ----
echo "----------------------------------------" | tee -a "$ACTIVE_LOG"
echo "[*] Stage: Nuclei Scan"             | tee -a "$ACTIVE_LOG"
if [[ -s "$ACTIVE/live_urls.txt" ]]; then
  awk '{print $1}' "$ACTIVE/live_urls.txt" >"$ACTIVE/http_200_urls.txt"
  if [[ -n "$NUCLEI_API_KEY" ]]; then
    nuclei -api-key "$NUCLEI_API_KEY" -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt" 2>>"$ACTIVE_ERR"
  else
    nuclei -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt" 2>>"$ACTIVE_ERR"
  fi
else
  echo "[!] No URLs for Nuclei. Skipping." | tee -a "$ACTIVE_LOG"
fi

# ---- 4) GF Pattern Matching ----
echo "----------------------------------------" | tee -a "$ACTIVE_LOG"
echo "[*] Stage: GF Pattern Matching"      | tee -a "$ACTIVE_LOG"
if [[ -s "$ACTIVE/http_200_urls.txt" ]]; then
  for pat in xss ssrf lfi; do
    gf "$pat" "$ACTIVE/http_200_urls.txt" >>"$ACTIVE/gf_${pat}_hits.txt" 2>>"$ACTIVE_ERR"
  done
else
  echo "[!] No URLs for GF. Skipping." | tee -a "$ACTIVE_LOG"
fi

# ---- 5) Sensitive Keyword Scan ----
echo "----------------------------------------" | tee -a "$ACTIVE_LOG"
echo "[*] Stage: Sensitive Keyword Scan"   | tee -a "$ACTIVE_LOG"
if [[ -f "$PASSIVE_FOLDER/sensitive_words.txt" ]]; then
  grep -iFf "$PASSIVE_FOLDER/sensitive_words.txt" "$ACTIVE/http_200_urls.txt" >"$ACTIVE/sensitive_matches.txt" 2>>"$ACTIVE_ERR" || true
else
  echo "[!] sensitive_words.txt missing. Skipping." | tee -a "$ACTIVE_LOG"
fi

# ---- Final Summary ----
echo "========================================" | tee -a "$ACTIVE_LOG"
echo "[✓] Active Recon Finished."           | tee -a "$ACTIVE_LOG"
echo "[✓] Outputs saved in: $ACTIVE"       | tee -a "$ACTIVE_LOG"

# ---- Continue to Exploitation ----
echo
read -rp "[?] Continue to Exploitation phase? [y/n]: " ans
[[ "$ans" =~ ^[Yy]$ ]] && bash coreexploit.sh --dir "$PASSIVE_FOLDER"
