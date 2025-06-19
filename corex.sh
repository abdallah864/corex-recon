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

Usage: $0 <command> [options]

Commands:
  install       Install all dependencies
  passive       Run passive recon
  active        Run active recon
  exploit       Run exploitation phase
  report        Generate summary report
  all           Run full pipeline (install → passive → active → exploit → report)
  menu          Interactive menu
  -h, --help    Show this message and exit

Options:
  --dry-run     [Optional] Show commands without executing them
  --verbose     Enable verbose output
  --output-dir  Specify base output directory

Examples:
  $0 all
  $0 passive --dry-run
  $0 active --output-dir /tmp/recon
EOF
}

# Default flags
DRY_RUN=false
VERBOSE=false
USER_OUTDIR=""

# Parse global options
while [[ $# -gt 0 && "$1" =~ ^- ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=true; shift ;;
    --verbose)    VERBOSE=true; shift ;;
    --output-dir) USER_OUTDIR="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *)            break ;;
  esac
done

# Helper to run commands (supports dry-run and verbose)
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

# Stage: install dependencies
install_deps() {
  echo -e "${CYAN}[+] Installing dependencies...${RESET}"
  run_cmd ./install.sh
  echo -e "${GREEN}[✓] Dependencies installed.${RESET}"
}

# Stage: passive recon
run_passive() {
  echo -e "${CYAN}[+] Running passive recon...${RESET}"
  run_cmd ./coreleak.sh
  echo -e "${GREEN}[✓] Passive recon completed.${RESET}"
}

# Stage: active recon
run_active() {
  echo -e "${CYAN}[+] Running active recon...${RESET}"
  run_cmd ./coreactive.sh
  echo -e "${GREEN}[✓] Active recon completed.${RESET}"
}

# Stage: exploitation phase
run_exploit() {
  echo -e "${CYAN}[+] Running exploitation phase...${RESET}"
  run_cmd ./coreexploit.sh
  echo -e "${GREEN}[✓] Exploitation phase completed.${RESET}"
}

# Stage: generate summary report
run_report() {
  echo -e "${CYAN}[+] Generating summary report...${RESET}"
  run_cmd ./coreport.sh
  echo -e "${GREEN}[✓] Summary report generated.${RESET}"
}

# Interactive menu
interactive_menu() {
  PS3=$'\nSelect an option (or 0 to exit): '
  options=(
    "Install dependencies"
    "Passive recon"
    "Active recon"
    "Exploitation phase"
    "Generate report"
    "Run all stages"
    "Exit"
  )
  select opt in "${options[@]}"; do
    case $REPLY in
      1) install_deps ;;
      2) run_passive ;;
      3) run_active ;;
      4) run_exploit ;;
      5) run_report ;;
      6) install_deps; run_passive; run_active; run_exploit; run_report ;;
      7) echo -e "${CYAN}Goodbye!${RESET}"; exit 0 ;;
      *) echo -e "${RED}[!] Invalid option.${RESET}" ;;
    esac
  done
}

# Determine which command to run (default: all)
COMMAND="${1:-all}"

case "$COMMAND" in
  install) install_deps ;;
  passive) run_passive ;;
  active)  run_active ;;
  exploit) run_exploit ;;
  report)  run_report ;;
  all)     install_deps; run_passive; run_active; run_exploit; run_report ;;
  menu)    interactive_menu ;;
  *) echo -e "${RED}[!] Unknown command: $COMMAND${RESET}"; usage; exit 1 ;;
esac
