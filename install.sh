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
echo "    CoreX - Auto Setup & Installer      "
echo "========================================"

REQUIRED_TOOLS=(subfinder amass assetfinder httpx nuclei gf dalfox ffuf gau waybackurls subjs nmap python3)
PYTHON_TOOLS=(arjun)

LOG="install_log.txt"
touch "$LOG"

echo "[*] Checking required tools..."

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[!] $tool not found!"
        echo "   > Please install $tool manually or check documentation." | tee -a "$LOG"
    else
        echo "[✓] $tool installed." | tee -a "$LOG"
    fi
done

for ptool in "${PYTHON_TOOLS[@]}"; do
    if ! python3 -c "import $ptool" &>/dev/null; then
        echo "[!] Python tool '$ptool' not found!"
        echo "   > Install with: pip3 install $ptool" | tee -a "$LOG"
    else
        echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
    fi
done

echo "[*] Setup finished. Please review '$LOG' for any missing dependencies."
echo "   - For details, see the documentation or README.md."
