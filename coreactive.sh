#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "========================================"
echo "    CoreActive: Automated Active Recon  "
echo "========================================"

ACTIVE_LOG="active_log.txt"
ACTIVE_ERR="active_error_log.txt"
: > "$ACTIVE_LOG"
: > "$ACTIVE_ERR"

# ---- Get latest passive folder ----
FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
if [ ! -d "$FOLDER" ]; then
  echo "[!] No coreleak_* folder found. Run passive script first." | tee -a "$ACTIVE_LOG"
  exit 1
fi

ACTIVE="$FOLDER/active"
mkdir -p "$ACTIVE"

echo "[*] Target: $FOLDER" | tee -a "$ACTIVE_LOG"
echo "[*] Output will be saved in: $ACTIVE" | tee -a "$ACTIVE_LOG"

# ---- Tool Check ----
REQUIRED_TOOLS=(httpx nuclei gf nmap)
TOOL_MISSING=0
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool is not installed. Please run install.sh." | tee -a "$ACTIVE_LOG"
    TOOL_MISSING=1
  fi
done
if [ "$TOOL_MISSING" -eq 1 ]; then
  echo "[✗] One or more tools are missing. Exiting." | tee -a "$ACTIVE_LOG"
  exit 1
fi

# ---- Step 1: Run httpx on all filtered URLs ----
if [ -f "$FOLDER/urls_filtered.txt" ]; then
  echo "[*] Running httpx ..." | tee -a "$ACTIVE_LOG"
  if ! cat "$FOLDER/urls_filtered.txt" \
    | httpx -silent -status-code -title -tech-detect -ip -cname -location \
    > "$ACTIVE/live_urls.txt" 2>>"$ACTIVE_ERR"; then
    echo "[!] httpx failed." | tee -a "$ACTIVE_LOG"
  fi

  awk '$2 == 200' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_200.txt"
  awk '$2 == 403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_403.txt"
  awk '$2 != 200 && $2 != 403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_other.txt"

  echo "[*] HTTPx finished. 200: $(wc -l < "$ACTIVE/http_200.txt" 2>/dev/null), 403: $(wc -l < "$ACTIVE/http_403.txt" 2>/dev/null), Other: $(wc -l < "$ACTIVE/http_other.txt" 2>/dev/null)" | tee -a "$ACTIVE_LOG"
else
  echo "[!] $FOLDER/urls_filtered.txt not found. Skipping httpx step." | tee -a "$ACTIVE_LOG"
fi

# ---- Step 2: Run Nmap on IPs extracted from 200 responses ----
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Extracting IPs for Nmap scan ..." | tee -a "$ACTIVE_LOG"
  awk '{print $5}' "$ACTIVE/http_200.txt" | sort -u > "$ACTIVE/live_ips.txt"

  if [ -s "$ACTIVE/live_ips.txt" ]; then
    echo "[*] Running nmap on live IPs ..." | tee -a "$ACTIVE_LOG"
    if ! nmap -T4 -Pn -sV -iL "$ACTIVE/live_ips.txt" -oN "$ACTIVE/nmap_scan.txt" 2>>"$ACTIVE_ERR"; then
      echo "[!] nmap failed." | tee -a "$ACTIVE_LOG"
    fi
  else
    echo "[!] No live IPs found for Nmap." | tee -a "$ACTIVE_LOG"
  fi
else
  echo "[!] No HTTP 200 results. Skipping Nmap scan." | tee -a "$ACTIVE_LOG"
fi

# ---- Step 3: Run nuclei on HTTP 200 URLs ----
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Running nuclei on 200 OK URLs ..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200.txt" > "$ACTIVE/http_200_urls.txt"
  if ! nuclei -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt" 2>>"$ACTIVE_ERR"; then
    echo "[!] nuclei failed." | tee -a "$ACTIVE_LOG"
  fi
else
  echo "[!] No HTTP 200 URLs for nuclei scan." | tee -a "$ACTIVE_LOG"
fi

# ---- Step 4: Run GF patterns on HTTP 200 URLs ----
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Running GF patterns on 200 OK URLs ..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200.txt" > "$ACTIVE/http_200_urls.txt"
  for pattern in xss ssrf lfi; do
    if ! cat "$ACTIVE/http_200_urls.txt" | gf "$pattern" > "$ACTIVE/gf_${pattern}_hits.txt" 2>>"$ACTIVE_ERR"; then
      echo "[!] gf $pattern failed." | tee -a "$ACTIVE_LOG"
    fi
  done
else
  echo "[!] No HTTP 200 URLs for GF patterns." | tee -a "$ACTIVE_LOG"
fi

# ---- Step 5: Handle HTTP 403 URLs ----
if [ -s "$ACTIVE/http_403.txt" ]; then
  echo "[!] Detected HTTP 403 responses. Review in: $ACTIVE/http_403.txt" | tee -a "$ACTIVE_LOG"
  echo "[!] You may apply bypass tools manually on these endpoints." | tee -a "$ACTIVE_LOG"
else
  echo "[*] No HTTP 403 endpoints detected." | tee -a "$ACTIVE_LOG"
fi

# ---- Step 6: Scan for sensitive keywords ----
if [ -f "$FOLDER/sensitive_words.txt" ] && [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Scanning 200 URLs for sensitive keywords..." | tee -a "$ACTIVE_LOG"
  awk '{print $1}' "$ACTIVE/http_200.txt" \
    | grep -iFf "$FOLDER/sensitive_words.txt" \
    > "$ACTIVE/sensitive_matches.txt" 2>>"$ACTIVE_ERR"
  echo "[*] Sensitive keyword scan complete." | tee -a "$ACTIVE_LOG"
else
  echo "[!] sensitive_words.txt or http_200.txt missing. Skipping keyword scan." | tee -a "$ACTIVE_LOG"
fi

echo "========================================" | tee -a "$ACTIVE_LOG"
echo "[✓] Active Recon Finished." | tee -a "$ACTIVE_LOG"
echo "[✓] All output saved in: $ACTIVE/  (Log: $ACTIVE_LOG, Errors: $ACTIVE_ERR)"
