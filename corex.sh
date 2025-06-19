#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "==================================="
echo " 🧠 CoreX: Full Recon Automation 🔁"
echo "==================================="

# ANSI color codes
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

# Display usage information
usage() {
cat <<EOF
${CYAN}CoreX Recon Suite${RESET}

Usage: $0 [options]

Steps:
  1. Passive Recon     (coreleak.sh)
  2. Active Recon      (coreactive.sh)
  3. Exploitation      (coreexploit.sh)
  4. Report Generation (coreport.sh)

Options:
  --dry-run     [Optional] Show commands without executing them
  --verbose     Enable verbose output
  -h, --help    Show this help message and exit
EOF
}

# Default flags
DRY_RUN=false
VERBOSE=false

# Parse global options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --verbose) VERBOSE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) break ;;
  esac
done

# Helper to run commands
run_cmd() {
  if $DRY_RUN; then
    echo -e "${YELLOW}[dry-run] ➔${RESET} $*"
  else
    if $VERBOSE; then
      echo -e "${CYAN}[exec] ➔${RESET} $*"
    fi
    eval "$*"
  fi
}

START_TIME=$(date)
echo "[+] Started at: $START_TIME"
echo

# Step 1: Passive Recon
echo "[1] Passive Recon (coreleak.sh)"
run_cmd ./coreleak.sh || { echo "[!] coreleak.sh failed."; exit 1; }

# Step 2: Active Recon
echo "[2] Active Recon (coreactive.sh)"
run_cmd ./coreactive.sh || { echo "[!] coreactive.sh failed."; exit 1; }

# Step 3: Exploitation Phase
echo "[3] Exploitation (coreexploit.sh)"
run_cmd ./coreexploit.sh || { echo "[!] coreexploit.sh failed."; exit 1; }

# Step 4: Report Generation
echo "[4] Report Generation (coreport.sh)"
run_cmd ./coreport.sh || { echo "[!] coreport.sh failed."; exit 1; }

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
