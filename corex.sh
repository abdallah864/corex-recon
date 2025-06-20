#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

# Banner
cat << 'EOF'
 .----------------.  .----------------.  .----------------.  .----------------.    .----------------. 
| .--------------. || .--------------. || .--------------. || .--------------. |  | .--------------. |
| |     ______   | || |     ____     | || |  _______     | || |  _________   | |  | |  ____  ____  | |
| |   .' ___  |  | || |   .'    `.   | || | |_   __ \    | || | |_   ___  |  | |  | | |_  _||_  _| | |
| |  / .'   \_|  | || |  /  .--.  \  | || |   | |__) |   | || |   | |_  \_|  | |  | |   \ \  / /   | |
| |  | |         | || |  | |    | |  | || |   |  __ /    | || |   |  _|  _   | |  | |    > `' <    | |
| |  \ `.___.'\  | || |  \  `--'  /  | || |  _| |  \ \_  | || |  _| |___/ |  | |  | |  _/ /'`\ \_  | |
| |   `._____. ' | || |   `.____.'   | || | |____| |___| | || | |_________|  | |  | | |____||____| | |
| |              | || |              | || |              | || |              | |  | |              | |
| '--------------' || '--------------' || '--------------' || '--------------' |  | '--------------' |
 '----------------'  '----------------'  '----------------'  '----------------'    '----------------'   

             Recon Project Toolkit v1.0.1
EOF

# Usage function
echo
usage() {
  echo -e "
\033[1;36mCoreX Recon Suite\033[0m

Usage:
  ./corex.sh [all|passive|active|exploit|report] [target] [options]

Options:
  -t, --target TARGET     Set target (domain/subdomain)
  -d, --dir DIR           Use existing scan folder (coreleak_*) [overrides target/new run]
  -o, --output FILE       Custom output path for the report
  --phase PHASE           Generate report for one phase only [passive|active|exploit]
  --no-color              Disable colored output (for logs/scripts)
  -h, --help              Show this help message

Examples:
  ./corex.sh                   # Full recon (asks for target)
  ./corex.sh passive           # Passive phase only (asks for target)
  ./corex.sh active -d coreleak_example.com_20250614-1
  ./corex.sh all -t inDrive.com
  ./corex.sh report -d coreleak_inDrive.com_20250614-2 --output bugbounty.txt --phase exploit
"
}

# --- Parse Args ---
STEP="all"
TARGET=""
SCAN_DIR=""
CUSTOM_OUT=""
PHASE=""
COLOR=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    passive|active|exploit|report|all) STEP="$1"; shift ;; 
    -t|--target) TARGET="$2"; shift 2 ;; 
    -d|--dir|--folder) SCAN_DIR="$2"; shift 2 ;; 
    -o|--output) CUSTOM_OUT="$2"; shift 2 ;; 
    --phase) PHASE="$2"; shift 2 ;; 
    --no-color) COLOR=false; shift ;; 
    -h|--help) usage; exit 0 ;; 
    *) TARGET="$1"; shift ;; 
  esac
done

# --- Color Helper ---
colored() {
  if $COLOR; then
    case "$2" in
      "red") echo -e "\033[1;31m$1\033[0m";;
      "yellow") echo -e "\033[1;33m$1\033[0m";;
      "green") echo -e "\033[1;32m$1\033[0m";;
      *) echo "$1";;
    esac
  else
    echo "$1"
  fi
}

# --- Target or Folder Detection ---
if [[ -n "$SCAN_DIR" ]]; then
  OUTPUT_DIR="$SCAN_DIR"
else
  while [[ -z "$TARGET" ]]; do
    read -rp "Enter target (domain or subdomain): " TARGET
  done
  TS=$(date +%Y%m%d_%H%M%S)
  SERIAL_FILE=".coreleak_serial_${TARGET}"
  SERIAL=1
  if [ -f "$SERIAL_FILE" ]; then
    SERIAL=$(( $(cat "$SERIAL_FILE") + 1 ))
  fi
  echo "$SERIAL" > "$SERIAL_FILE"
  OUTPUT_DIR="coreleak_${TARGET}_${TS}-${SERIAL}"
fi

export COREX_TARGET="$TARGET"
export COREX_OUTDIR="$OUTPUT_DIR"

START_TIME=$(date)
echo "[+] Started at: $START_TIME"
echo "[+] Scan folder: $OUTPUT_DIR"

# --- Chain Logic Helper ---
run_and_chain() {
  local SCRIPT=$1; shift
  local NEXT=$1; shift
  local MSG=$1; shift
  bash "$SCRIPT" -t "$TARGET" -d "$OUTPUT_DIR" "$@"
  echo
  if [[ -n "$NEXT" ]]; then
    read -rp "[*] Continue to $MSG phase? (y/n): " GOON
    if [[ "$GOON" == "y" ]]; then
      run_and_chain "$NEXT" "" "" "$@"
    fi
  fi
}

# --- Main Switch ---
case "$STEP" in
  all)
    bash coreleak.sh   -t "$TARGET" -d "$OUTPUT_DIR"
    bash coreactive.sh -t "$TARGET" -d "$OUTPUT_DIR"
    bash coreexploit.sh -t "$TARGET" -d "$OUTPUT_DIR"
    bash coreport.sh   -d "$OUTPUT_DIR" ${CUSTOM_OUT:+-o "$CUSTOM_OUT"} ${PHASE:+--phase "$PHASE"}
    ;;
  passive)
    run_and_chain coreleak.sh coreactive.sh "Active" ;;
  active)
    run_and_chain coreactive.sh coreexploit.sh "Exploitation" ;;
  exploit)
    run_and_chain coreexploit.sh coreport.sh "Report" ;;
  report)
    bash coreport.sh -d "$OUTPUT_DIR" ${CUSTOM_OUT:+-o "$CUSTOM_OUT"} ${PHASE:+--phase "$PHASE"}
    ;;
  *)
    usage; exit 1 ;;
esac

# Add summary and reporting logic below as before
