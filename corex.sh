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

usage() {
  echo -e "
\033[1;36mCoreX Recon Suite\033[0m

Usage:
  ./corex.sh [step] [--verbose]

Steps:
  all         Run full pipeline (default: all steps)
  passive     Run Passive Recon only (coreleak.sh)
  active      Run Active Recon only (coreactive.sh)
  exploit     Run Exploitation phase only (coreexploit.sh)
  report      Run Report Generation only (coreport.sh)

Options:
  --verbose   Show script output in real time
  -h, --help  Show this help message and exit

Examples:
  ./corex.sh                   # Run the full recon workflow (all steps)
  ./corex.sh passive           # Run passive recon stage only
  ./corex.sh exploit --verbose # Run exploitation phase and show all output
  ./corex.sh report            # Generate the final report only
"
}

# Parse arguments
STEP="all"
VERBOSE=false

for arg in "$@"; do
  case "$arg" in
    passive|active|exploit|report|all) STEP="$arg" ;;
    --verbose) VERBOSE=true ;;
    -h|--help) usage; exit 0 ;;
  esac
done

START_TIME=$(date)
echo "[+] Started at: $START_TIME"
echo

run_phase() {
  PHASE="$1"
  SCRIPT="$2"
  LABEL="$3"
  echo "[$PHASE] $LABEL"
  if $VERBOSE; then
    bash "$SCRIPT" || { echo "[!] $SCRIPT failed."; exit 1; }
  else
    bash "$SCRIPT" > /dev/null || { echo "[!] $SCRIPT failed."; exit 1; }
  fi
}

case "$STEP" in
  all)
    run_phase "1" coreleak.sh      "Passive Recon (coreleak.sh)"
    run_phase "2" coreactive.sh    "Active Recon (coreactive.sh)"
    run_phase "3" coreexploit.sh   "Exploitation (coreexploit.sh)"
    run_phase "4" coreport.sh      "Report Generation (coreport.sh)"
    ;;
  passive)
    run_phase "1" coreleak.sh      "Passive Recon (coreleak.sh)"
    ;;
  active)
    run_phase "2" coreactive.sh    "Active Recon (coreactive.sh)"
    ;;
  exploit)
    run_phase "3" coreexploit.sh   "Exploitation (coreexploit.sh)"
    ;;
  report)
    run_phase "4" coreport.sh      "Report Generation (coreport.sh)"
    ;;
  *)
    usage; exit 1
    ;;
esac

echo
FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
REPORT="$FOLDER/report/summary.txt"

if [ -f "$REPORT" ] && grep -qiE 'token|password|secret|vuln|POC|critical|high' "$REPORT"; then
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
