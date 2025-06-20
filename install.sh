#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# Version: v1.0.1
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "========================================"
echo "    CoreX - Auto Setup & Installer      "
echo "========================================"

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run this script as root or with sudo."
    exit 1
fi

REQUIRED_TOOLS=(subfinder amass assetfinder httpx nuclei gf dalfox ffuf gau waybackurls subjs nmap python3)
PYTHON_TOOLS=(arjun)

LOG="install_log.txt"
ERR="error_log.txt"
: > "$LOG"
: > "$ERR"

declare -A TOOL_URLS
TOOL_URLS[subfinder]="https://github.com/projectdiscovery/subfinder#installation"
TOOL_URLS[amass]="https://github.com/owasp-amass/amass"
TOOL_URLS[assetfinder]="https://github.com/tomnomnom/assetfinder"
TOOL_URLS[httpx]="https://github.com/projectdiscovery/httpx#installation"
TOOL_URLS[nuclei]="https://github.com/projectdiscovery/nuclei#installation"
TOOL_URLS[gf]="https://github.com/tomnomnom/gf"
TOOL_URLS[dalfox]="https://github.com/hahwul/dalfox#install"
TOOL_URLS[ffuf]="https://github.com/ffuf/ffuf"
TOOL_URLS[gau]="https://github.com/lc/gau"
TOOL_URLS[waybackurls]="https://github.com/tomnomnom/waybackurls"
TOOL_URLS[subjs]="https://github.com/lc/subjs"
TOOL_URLS[nmap]="https://nmap.org/book/inst-windows.html"

FAILED_TOOLS=()

# ==== Go version check ====
GO_OK=false
if command -v go &>/dev/null; then
    GOVERSION=$(go version | awk '{print $3}' | cut -c3-)
    GOVERSION_MAIN=$(echo $GOVERSION | cut -d. -f1)
    GOVERSION_MINOR=$(echo $GOVERSION | cut -d. -f2)
    if [ "$GOVERSION_MAIN" -ge 1 ] && [ "$GOVERSION_MINOR" -ge 18 ]; then
        GO_OK=true
    fi
fi
if ! $GO_OK; then
    echo "[!] Go not found or version < 1.18. Installing Go 1.21.6 ..."
    wget -q https://go.dev/dl/go1.21.6.linux-amd64.tar.gz -O /tmp/go1.21.6.linux-amd64.tar.gz
    tar -C /usr/local -xzf /tmp/go1.21.6.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
    echo "[+] Go 1.21.6 installed." | tee -a "$LOG"
fi

echo "[*] Checking required tools..." | tee -a "$LOG"

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[!] $tool not found! Trying multiple installation methods..." | tee -a "$LOG"
        success=false

        case $tool in
            nuclei)
                go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && success=true
                ;;
            amass)
                go install github.com/owasp-amass/amass/v4/...@latest && success=true
                ;;
            dalfox)
                go install github.com/hahwul/dalfox/v2/cmd/dalfox@latest && success=true
                ;;
            ffuf)
                go install github.com/ffuf/ffuf@latest && success=true
                ;;
            gau)
                go install github.com/lc/gau@latest && success=true
                ;;
            waybackurls)
                go install github.com/tomnomnom/waybackurls@latest && success=true
                ;;
            subjs)
                go install github.com/lc/subjs@latest && success=true
                ;;
            assetfinder|gf)
                go install github.com/tomnomnom/${tool}@latest && success=true
                ;;
            httpx|subfinder)
                go install github.com/projectdiscovery/${tool}/v2/cmd/${tool}@latest && success=true
                ;;
            *)
                success=false
                ;;
        esac

        # apt fallback
        if ! $success; then
            apt-get update && apt-get install -y "$tool" && success=true
        fi

        # wget/manual binary fallback (example for dalfox)
        if ! $success; then
            if [ "$tool" = "dalfox" ]; then
                wget -q https://github.com/hahwul/dalfox/releases/latest/download/dalfox_linux_amd64 -O /usr/local/bin/dalfox && chmod +x /usr/local/bin/dalfox && success=true
            fi
            # Extend here for other tools if needed
        fi

        if command -v "$tool" &>/dev/null; then
            echo "[✓] $tool installed successfully." | tee -a "$LOG"
        else
            echo "[✗] Failed to auto-install $tool, please install manually!" | tee -a "$LOG"
            FAILED_TOOLS+=("$tool")
            if [[ -n "${TOOL_URLS[$tool]:-}" ]]; then
                echo "   > Manual install: ${TOOL_URLS[$tool]}" | tee -a "$LOG"
            fi
        fi
    else
        echo "[✓] $tool installed." | tee -a "$LOG"
    fi
done

# ==== Python tools ====
for ptool in "${PYTHON_TOOLS[@]}"; do
    if ! python3 -c "import $ptool" &>/dev/null; then
        pip3 install "$ptool" >>"$LOG" 2>>"$ERR"
        if python3 -c "import $ptool" &>/dev/null; then
            echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
        else
            echo "[✗] Failed to install Python tool '$ptool', install manually: pip3 install $ptool" | tee -a "$LOG"
            FAILED_TOOLS+=("$ptool")
        fi
    else
        echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
    fi
done

# ==== Final summary ====
if [ "${#FAILED_TOOLS[@]}" -gt 0 ]; then
    echo -e "\n[✗] Some tools failed to install automatically:\n" | tee -a "$LOG"
    for t in "${FAILED_TOOLS[@]}"; do
        echo "   - $t (${TOOL_URLS[$t]})" | tee -a "$LOG"
    done
    echo -e "\n[!] Please install these manually and re-run the script if needed." | tee -a "$LOG"
else
    echo -e "\n[✓] All required tools installed!" | tee -a "$LOG"
fi

echo "[*] Setup finished. Please review '$LOG' for any missing dependencies."
echo "   - For details, see the documentation or README.md."
echo "========================================"
