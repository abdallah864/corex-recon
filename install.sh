#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.
# =============================================================================

echo "========================================"
echo "    CoreX - Auto Setup & Installer      "
echo "========================================"

# === 1. Check root privileges ===
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

# === 2. Check Go version ===
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
        echo "[!] $tool not found!" | tee -a "$LOG"
        success=false

        # Special handling for nuclei (multi-method)
        if [ "$tool" = "nuclei" ]; then
            {
                go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && success=true
                export PATH=$PATH:$(go env GOPATH)/bin
                command -v nuclei &>/dev/null && success=true
                $success || { apt-get update && apt-get install -y nuclei && command -v nuclei &>/dev/null && success=true; }
                $success || {
                    wget -qO- https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_2.9.17_linux_amd64.zip | bsdtar -xvf- -C /usr/local/bin/ && chmod +x /usr/local/bin/nuclei* && command -v nuclei &>/dev/null && success=true;
                }
            } >>"$LOG" 2>>"$ERR"
        # Special handling for amass (apt if go fails)
        elif [ "$tool" = "amass" ]; then
            go install github.com/owasp-amass/amass/v4/...@latest 2>>"$ERR" || apt-get update && apt-get install -y amass 2>>"$ERR"
            command -v amass &>/dev/null && success=true
        # General Go tools (try all common orgs)
        else
            go install "github.com/projectdiscovery/${tool}/v2/cmd/${tool}@latest" 2>>"$ERR" || \
            go install "github.com/tomnomnom/${tool}@latest" 2>>"$ERR" || \
            go install "github.com/lc/${tool}@latest" 2>>"$ERR" || \
            apt-get update && apt-get install -y "$tool" 2>>"$ERR"
            command -v "$tool" &>/dev/null && success=true
        fi

        if command -v "$tool" &>/dev/null; then
            echo "[✓] $tool installed successfully." | tee -a "$LOG"
        else
            echo "   > Failed to install $tool, please install manually." | tee -a "$LOG"
            if [[ -n "${TOOL_URLS[$tool]:-}" ]]; then
                echo "   > For install help: ${TOOL_URLS[$tool]}" | tee -a "$LOG"
            fi
        fi
    else
        echo "[✓] $tool installed." | tee -a "$LOG"
    fi
done

for ptool in "${PYTHON_TOOLS[@]}"; do
    if ! python3 -c "import $ptool" &>/dev/null; then
        echo "[!] Python tool '$ptool' not found!" | tee -a "$LOG"
        echo "   > Installing with: pip3 install $ptool" | tee -a "$LOG"
        pip3 install $ptool >>"$LOG" 2>>"$ERR"
        if python3 -c "import $ptool" &>/dev/null; then
            echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
        else
            echo "[✗] Failed to install Python tool '$ptool', install manually." | tee -a "$LOG"
        fi
    else
        echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
    fi
done

echo "[*] Setup finished. Please review '$LOG' for any missing dependencies."
echo "   - For details, see the documentation or README.md."
echo "========================================"
