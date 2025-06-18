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
echo "      CoreReport: Recon Summary Tool    "
echo "========================================"

# Get the latest passive folder
FOLDER=$(ls -dt coreleak_* 2>/dev/null | head -n 1)
if [ ! -d "$FOLDER" ]; then
    echo "[!] No coreleak_* folder found. Run other scripts first."
    exit 1
fi

REPORT="$FOLDER/report"
mkdir -p "$REPORT"

SUMMARY="$REPORT/summary.txt"
SUMMARY_CSV="$REPORT/summary.csv"
echo "📌 Target Summary - $FOLDER" > "$SUMMARY"
echo "Generated: $(date)" >> "$SUMMARY"
echo "----------------------------------------" >> "$SUMMARY"

echo "Type,Tool,Details,Severity" > "$SUMMARY_CSV"

# 1. Live endpoints
if [ -f "$FOLDER/active/live_urls.txt" ]; then
    echo -e "\n🟢 Live Endpoints:" >> "$SUMMARY"
    sort -u "$FOLDER/active/live_urls.txt" >> "$SUMMARY"
fi

# 2. GF Hits (merged)
if [ -f "$FOLDER/merged/gf_all_hits.txt" ]; then
    echo -e "\n🔥 GF Patterns Detected:" >> "$SUMMARY"
    sort -u "$FOLDER/merged/gf_all_hits.txt" >> "$SUMMARY"
    grep -i . "$FOLDER/merged/gf_all_hits.txt" | while IFS= read -r line; do
        echo "GF Pattern,GF,$line," >> "$SUMMARY_CSV"
    done
fi

# 3. Dalfox Results
if [ -f "$FOLDER/exploit/dalfox_result.txt" ]; then
    echo -e "\n🚨 Dalfox Findings:" >> "$SUMMARY"
    grep -Ei 'VULN|POC|target|http' "$FOLDER/exploit/dalfox_result.txt" | sort -u >> "$SUMMARY"
    grep -Ei 'VULN|POC|target|http' "$FOLDER/exploit/dalfox_result.txt" | while IFS= read -r line; do
        if echo "$line" | grep -qi 'high'; then
            sev="high"
        elif echo "$line" | grep -qi 'medium'; then
            sev="medium"
        elif echo "$line" | grep -qi 'low'; then
            sev="low"
        else
            sev=""
        fi
        echo "XSS,Dalfox,$line,$sev" >> "$SUMMARY_CSV"
    done
fi

# 4. Manual Injection Notes
if [ -f "$FOLDER/exploit/manual_injection.txt" ]; then
    echo -e "\n🧪 Manual Injection Results:" >> "$SUMMARY"
    grep -Ei 'http|location|x-powered|200 OK|403|302' "$FOLDER/exploit/manual_injection.txt" | sort -u >> "$SUMMARY"
    grep -Ei 'http|location|x-powered|200 OK|403|302' "$FOLDER/exploit/manual_injection.txt" | while IFS= read -r line; do
        echo "Manual,Injection,$line," >> "$SUMMARY_CSV"
    done
fi

# 5. Nuclei Highlights
if [ -f "$FOLDER/active/nuclei_report.txt" ]; then
    echo -e "\n📍 Nuclei Vulnerabilities:" >> "$SUMMARY"
    grep -Ei 'medium|high' "$FOLDER/active/nuclei_report.txt" | sort -u >> "$SUMMARY"
    grep -Ei 'medium|high|low' "$FOLDER/active/nuclei_report.txt" | while IFS= read -r line; do
        if echo "$line" | grep -qi 'high'; then
            sev="high"
        elif echo "$line" | grep -qi 'medium'; then
            sev="medium"
        elif echo "$line" | grep -qi 'low'; then
            sev="low"
        else
            sev=""
        fi
        echo "Vuln,Nuclei,$line,$sev" >> "$SUMMARY_CSV"
    done
fi

# 6. Sensitive Keyword Matches
if [ -f "$FOLDER/active/sensitive_matches.txt" ]; then
    echo -e "\n🔐 Sensitive Keywords Found:" >> "$SUMMARY"
    sort -u "$FOLDER/active/sensitive_matches.txt" >> "$SUMMARY"
    grep -i . "$FOLDER/active/sensitive_matches.txt" | while IFS= read -r line; do
        echo "Sensitive,Keyword,$line," >> "$SUMMARY_CSV"
    done
fi

# 7. FFUF Directories Summary
if [ -d "$FOLDER/exploit" ]; then
    echo -e "\n📁 FFUF Findings:" >> "$SUMMARY"
    find "$FOLDER/exploit" -name "ffuf_*.csv" | while IFS= read -r csv; do
        echo "$(basename "$csv"):" >> "$SUMMARY"
        grep -i ",200," "$csv" | cut -d, -f1 | sort -u >> "$SUMMARY"
        grep -i ",200," "$csv" | cut -d, -f1 | while IFS= read -r url; do
            echo "Directory,FFUF 200,$url," >> "$SUMMARY_CSV"
        done
        echo "---" >> "$SUMMARY"
    done
fi

# 8. FFUF 403 Detection
if [ -d "$FOLDER/exploit" ]; then
    echo -e "\n🚫 FFUF - Forbidden (403) Directories:" >> "$SUMMARY"
    find "$FOLDER/exploit" -name "ffuf_*.csv" | while IFS= read -r csv; do
        grep -i ",403," "$csv" | cut -d, -f1 | sort -u >> "$SUMMARY"
        grep -i ",403," "$csv" | cut -d, -f1 | while IFS= read -r url; do
            echo "Directory,FFUF 403,$url," >> "$SUMMARY_CSV"
        done
    done
fi

# 9. Add notes/screenshot section
echo -e "\n📝 Notes / Screenshots Section (Add manually if needed):" >> "$SUMMARY"
echo "Notes,Screenshot,Add your notes/screenshots here," >> "$SUMMARY_CSV"

echo -e "\n✅ Report Generated: $SUMMARY"
echo "✅ CSV Report Generated: $SUMMARY_CSV"
