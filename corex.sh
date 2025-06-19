k#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "==================================="
echo " 🧠 CoreX: Full Recon Automation 🔁"
echo "==================================="

# Display usage information
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo -e "
\033[1;36mCoreX Recon Suite\033[0m

Usage: ./corex.sh [--verbose]

Steps:
  1. Passive Recon     (coreleak.sh)
  2. Active Recon      (coreactive.sh)
  3. Exploitation      (coreexploit.sh)
  4. Report Generation (coreport.sh)

Options:
  --verbose   Show script output in real time
  -h, --help  Show this help message and exit
"
  exit 0
fi

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

START_TIME=$(date)
echo "[+] Started at: $START_TIME"
echo

# Step 1: Passive Recon
echo "[1] Passive Recon (coreleak.sh)"
$VERBOSE && bash coreleak.sh || bash coreleak.sh > /dev/null || { echo "[!] coreleak.sh failed."; exit 1; }

# Step 2: Active Recon
echo "[2] Active Recon (coreactive.sh)"
$VERBOSE && bash coreactive.sh || bash coreactive.sh > /dev/null || { echo "[!] coreactive.sh failed."; exit 1; }

# Step 3: Exploitation Phase
echo "[3] Exploitation (coreexploit.sh)"
$VERBOSE && bash coreexploit.sh || bash coreexploit.sh > /dev/null || { echo "[!] coreexploit.sh failed."; exit 1; }

# Step 4: Report Generation
echo "[4] Report Generation (coreport.sh)"
$VERBOSE && bash coreport.sh || bash coreport.sh > /dev/null || { echo "[!] coreport.sh failed."; exit 1; }

echo
# تحديد آخر مجلد coreleak للحصول على التقرير
FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
REPORT="$FOLDER/report/summary.txt"

# تنبيه لو فيه نتائج حساسة
if grep -qiE 'token|password|secret|vuln|POC|critical|high' "$REPORT"; then
    echo "🚨 [!] Alert: Important findings detected in the final report!"
    echo "📄 Review the report at: $REPORT"
else
    echo "✅ [OK] No critical findings highlighted in report."
fi

END_TIME=$(date)
echo
echo "==================================="
echo "✅ CoreX Completed."
echo "🕒 Start Time : $START_TIME"
echo "🕒 End Time   : $END_TIME"
echo "📁 Report Path: $REPORT"

