#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# Version: v1.0.2
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "========================================"
echo "      CoreReport: Recon Summary Tool    "
echo "========================================"

usage() {
  echo "
  Usage: ./coreport.sh [-d DIR|--dir DIR] [--phase <phase>] [-o FILE|--output FILE]

  Options:
    -d, --dir DIR       Specify the scan folder (default: latest coreleak_*)
    --phase PHASE       Only report specific phase (active/exploit/report)
    -o, --output FILE   Output report to specific file
    -h, --help          Show this help message

  Example:
    ./coreport.sh -d coreleak_example.com_20250614173033-1
    ./coreport.sh --phase exploit
    ./coreport.sh -o my_custom_report.txt
"
  exit 0
}

FOLDER=""
PHASE=""
OUTFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dir)       FOLDER="$2"; shift 2;;
    --phase)        PHASE="$2"; shift 2;;
    -o|--output)    OUTFILE="$2"; shift 2;;
    -h|--help)      usage;;
    *)              usage;;
  esac
done

if [[ -z "$FOLDER" ]]; then
  FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
fi
if [ -z "$FOLDER" ] || [ ! -d "$FOLDER" ]; then
  echo "[!] No coreleak_* folder found. Run other scripts first."
  exit 1
fi

LOG="report_log.txt"
ERR="report_error_log.txt"
: > "$LOG"
: > "$ERR"

REPORT="$FOLDER/report"
mkdir -p "$REPORT"

if [[ -z "$OUTFILE" ]]; then
  SUMMARY="$REPORT/summary.txt"
else
  SUMMARY="$OUTFILE"
fi
SUMMARY_CSV="$REPORT/summary.csv"

echo "📌 Target Summary - $FOLDER (v1.0.2)" > "$SUMMARY"
echo "Generated: $(date)" >> "$SUMMARY"
echo "----------------------------------------" >> "$SUMMARY"

echo "Type,Tool,Details,Severity" > "$SUMMARY_CSV"

section() {
  echo -e "\n$1" >> "$SUMMARY"
}

##### -- 1. Quick Stats Summary
live_count=0
high_count=0
xss_count=0
sensitive_count=0

# Count live endpoints
if [ -f "$FOLDER/active/live_urls.txt" ]; then
  live_count=$(wc -l < "$FOLDER/active/live_urls.txt")
fi
# Count Dalfox findings
if [ -f "$FOLDER/exploit/dalfox_result.txt" ]; then
  high_count=$(grep -ci 'high' "$FOLDER/exploit/dalfox_result.txt")
  xss_count=$(grep -Ei 'VULN|POC|target|http' "$FOLDER/exploit/dalfox_result.txt" | wc -l)
fi
# Count Nuclei high
if [ -f "$FOLDER/active/nuclei_report.txt" ]; then
  high_count=$(( high_count + $(grep -ci 'high' "$FOLDER/active/nuclei_report.txt") ))
fi
# Count sensitive keywords
if [ -f "$FOLDER/active/sensitive_matches.txt" ]; then
  sensitive_count=$(wc -l < "$FOLDER/active/sensitive_matches.txt")
fi

echo "Quick Summary: [Live: $live_count] [High/Critical: $high_count] [XSS: $xss_count] [Sensitive: $sensitive_count]" >> "$SUMMARY"
echo "----------------------------------------" >> "$SUMMARY"

##### -- PHASE FILTERING --
add_section() {
  local sec_name="$1"
  local sec_cmd="$2"
  if [[ -z "$PHASE" || "$PHASE" == "$sec_name" ]]; then
    eval "$sec_cmd"
  fi
}

missing_all=1

# 1. Live Endpoints
add_section "active" '
if [ -f "$FOLDER/active/live_urls.txt" ]; then
  section "Live Endpoints:"
  sort -u "$FOLDER/active/live_urls.txt" >> "$SUMMARY"
  missing_all=0
else
  echo "[!] live_urls.txt not found" >> "$ERR"
fi
'

# 2. GF Hits
add_section "active" '
if [ -f "$FOLDER/merged/gf_all_hits.txt" ]; then
  section "GF Patterns Detected:"
  sort -u "$FOLDER/merged/gf_all_hits.txt" >> "$SUMMARY"
  grep -i . "$FOLDER/merged/gf_all_hits.txt" | while IFS= read -r line; do
    echo "GF Pattern,GF,$line," >> "$SUMMARY_CSV"
  done
  missing_all=0
elif compgen -G "$FOLDER/active/gf_*_hits.txt" > /dev/null; then
  section "GF Patterns Detected:"
  cat "$FOLDER"/active/gf_*_hits.txt | sort -u >> "$SUMMARY"
  cat "$FOLDER"/active/gf_*_hits.txt | while IFS= read -r line; do
    echo "GF Pattern,GF,$line," >> "$SUMMARY_CSV"
  done
  missing_all=0
else
  echo "[!] gf hits not found" >> "$ERR"
fi
'

# 3. Dalfox Results
add_section "exploit" '
if [ -f "$FOLDER/exploit/dalfox_result.txt" ]; then
  section "Dalfox Findings:"
  grep -Ei "VULN|POC|target|http" "$FOLDER/exploit/dalfox_result.txt" | sort -u >> "$SUMMARY"
  grep -Ei "VULN|POC|target|http" "$FOLDER/exploit/dalfox_result.txt" | while IFS= read -r line; do
    if echo "$line" | grep -qi "high"; then sev="high"
    elif echo "$line" | grep -qi "medium"; then sev="medium"
    elif echo "$line" | grep -qi "low"; then sev="low"
    else sev=""
    fi
    echo "XSS,Dalfox,$line,$sev" >> "$SUMMARY_CSV"
  done
  missing_all=0
else
  echo "[!] dalfox_result.txt not found" >> "$ERR"
fi
'

# 4. Manual Injection Notes
add_section "exploit" '
if [ -f "$FOLDER/exploit/manual_injection.txt" ]; then
  section "Manual Injection Results:"
  grep -Ei "http|location|x-powered|200 OK|403|302" "$FOLDER/exploit/manual_injection.txt" | sort -u >> "$SUMMARY"
  grep -Ei "http|location|x-powered|200 OK|403|302" "$FOLDER/exploit/manual_injection.txt" | while IFS= read -r line; do
    echo "Manual,Injection,$line," >> "$SUMMARY_CSV"
  done
  missing_all=0
else
  echo "[!] manual_injection.txt not found" >> "$ERR"
fi
'

# 5. Nuclei Highlights
add_section "active" '
if [ -f "$FOLDER/active/nuclei_report.txt" ]; then
  section "Nuclei Vulnerabilities:"
  grep -Ei "medium|high" "$FOLDER/active/nuclei_report.txt" | sort -u >> "$SUMMARY"
  grep -Ei "medium|high|low" "$FOLDER/active/nuclei_report.txt" | while IFS= read -r line; do
    if echo "$line" | grep -qi "high"; then sev="high"
    elif echo "$line" | grep -qi "medium"; then sev="medium"
    elif echo "$line" | grep -qi "low"; then sev="low"
    else sev=""
    fi
    echo "Vuln,Nuclei,$line,$sev" >> "$SUMMARY_CSV"
  done
  missing_all=0
else
  echo "[!] nuclei_report.txt not found" >> "$ERR"
fi
'

# 6. Sensitive Keywords
add_section "active" '
if [ -f "$FOLDER/active/sensitive_matches.txt" ]; then
  section "Sensitive Keywords Found:"
  sort -u "$FOLDER/active/sensitive_matches.txt" >> "$SUMMARY"
  grep -i . "$FOLDER/active/sensitive_matches.txt" | while IFS= read -r line; do
    echo "Sensitive,Keyword,$line," >> "$SUMMARY_CSV"
  done
  missing_all=0
else
  echo "[!] sensitive_matches.txt not found" >> "$ERR"
fi
'

# 7. FFUF 200 Findings
add_section "exploit" '
if [ -d "$FOLDER/exploit" ]; then
  section "FFUF Findings (200 OK):"
  find "$FOLDER/exploit" -name "ffuf_*.csv" | while IFS= read -r csv; do
    echo "$(basename "$csv"):" >> "$SUMMARY"
    grep -i ",200," "$csv" | cut -d, -f1 | sort -u >> "$SUMMARY"
    grep -i ",200," "$csv" | cut -d, -f1 | while IFS= read -r url; do
      echo "Directory,FFUF 200,$url," >> "$SUMMARY_CSV"
    done
    echo "---" >> "$SUMMARY"
  done
  missing_all=0
else
  echo "[!] FFUF folder missing" >> "$ERR"
fi
'

# 8. FFUF 403 Findings
add_section "exploit" '
if [ -d "$FOLDER/exploit" ]; then
  section "FFUF Forbidden (403) Directories:"
  find "$FOLDER/exploit" -name "ffuf_*.csv" | while IFS= read -r csv; do
    grep -i ",403," "$csv" | cut -d, -f1 | sort -u >> "$SUMMARY"
    grep -i ",403," "$csv" | cut -d, -f1 | while IFS= read -r url; do
      echo "Directory,FFUF 403,$url," >> "$SUMMARY_CSV"
    done
  done
  missing_all=0
fi
'

# 9. Notes Section (always included)
section "Notes / Screenshots Section:"
echo "Notes,Screenshot,Add your notes/screenshots here," >> "$SUMMARY_CSV"

if [[ "$missing_all" == 1 ]]; then
  echo -e "\n[!] No results found for this phase." | tee -a "$SUMMARY"
fi

echo -e "\n Report Generated: $SUMMARY"
echo " CSV Report Generated: $SUMMARY_CSV"
echo " Log File: $LOG | Errors: $ERR"
