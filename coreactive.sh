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

# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.

echo "========================================"
echo "    CoreActive: Automated Active Recon  "
echo "========================================"

# Get latest passive folder
FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
if [ ! -d "$FOLDER" ]; then
  echo "[!] No coreleak_* folder found. Run passive script first."
  exit 1
fi

ACTIVE="$FOLDER/active"
mkdir -p "$ACTIVE"

echo "[] Target: $FOLDER"
echo "[] Output will be saved in: $ACTIVE"

# Check required tools
REQUIRED_TOOLS=(httpx nuclei gf nmap)
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[!] $tool is not installed. Please run install.sh."
    exit 1
  fi
done

# Step 1: Run httpx on all filtered URLs
if [ -f "$FOLDER/urls_filtered.txt" ]; then
  echo "[*] Running httpx ..."
  cat "$FOLDER/urls_filtered.txt" \
    | httpx -silent -status-code -title -tech-detect -ip -cname -location \
    > "$ACTIVE/live_urls.txt"

  awk '$2 == 200' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_200.txt"
  awk '$2 == 403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_403.txt"
  awk '$2 != 200 && $2 != 403' "$ACTIVE/live_urls.txt" > "$ACTIVE/http_other.txt"

  echo "[*] HTTPx finished. 200: $(wc -l < "$ACTIVE/http_200.txt" 2>/dev/null), 403: $(wc -l < "$ACTIVE/http_403.txt" 2>/dev/null), Other: $(wc -l < "$ACTIVE/http_other.txt" 2>/dev/null)"
fi

# Step 2: Run Nmap on IPs extracted from 200 responses
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Extracting IPs for Nmap scan ..."
  awk '{print $5}' "$ACTIVE/http_200.txt" | sort -u > "$ACTIVE/live_ips.txt"

  if [ -s "$ACTIVE/live_ips.txt" ]; then
    echo "[*] Running nmap on live IPs ..."
    nmap -T4 -Pn -sV -iL "$ACTIVE/live_ips.txt" -oN "$ACTIVE/nmap_scan.txt"
  fi
fi

# Step 3: Run nuclei on HTTP 200 URLs
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Running nuclei on 200 OK URLs ..."
  awk '{print $1}' "$ACTIVE/http_200.txt" > "$ACTIVE/http_200_urls.txt"
  nuclei -l "$ACTIVE/http_200_urls.txt" -o "$ACTIVE/nuclei_report.txt"
fi

# Step 4: Run GF patterns on HTTP 200 URLs
if [ -s "$ACTIVE/http_200.txt" ]; then
  echo "[*] Running GF patterns on 200 OK URLs ..."
  awk '{print $1}' "$ACTIVE/http_200.txt" > "$ACTIVE/http_200_urls.txt"
  for pattern in xss ssrf lfi; do
    cat "$ACTIVE/http_200_urls.txt" | gf "$pattern" > "$ACTIVE/gf_${pattern}_hits.txt"
  done
fi

# Step 5: Handle HTTP 403 URLs
if [ -s "$ACTIVE/http_403.txt" ]; then
  echo "[!] Detected HTTP 403 responses. Review in: $ACTIVE/http_403.txt"
  echo "[!] You may apply bypass tools manually on these endpoints."
fi

# Step 6: Scan for sensitive keywords
if [ -f "$FOLDER/sensitive_words.txt" ]; then
  echo "[*] Scanning 200 URLs for sensitive keywords..."
  awk '{print $1}' "$ACTIVE/http_200.txt" \
    | grep -iFf "$FOLDER/sensitive_words.txt" \
    > "$ACTIVE/sensitive_matches.txt"
fi

echo "✅ Active Recon Finished."
echo "📁 All output saved in: $ACTIVE/"
