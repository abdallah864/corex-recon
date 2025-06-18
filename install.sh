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

# Ensure Go is installed
if ! command -v go &>/dev/null; then
    echo "[!] Go not found! Installing Go 1.21.6 ..."
    wget -q https://go.dev/dl/go1.21.6.linux-amd64.tar.gz -O /tmp/go1.21.6.linux-amd64.tar.gz
    tar -C /usr/local -xzf /tmp/go1.21.6.linux-amd64.tar.gz
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    source ~/.bashrc
fi

echo "[*] Checking required tools..."

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[!] $tool not found!"

        # Special handling for nuclei (multi-method)
        if [ "$tool" = "nuclei" ]; then
            echo "   > Attempting to install nuclei via Go ..."
            go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest 2>/dev/null
            export PATH=$PATH:$(go env GOPATH)/bin
            if ! command -v nuclei &>/dev/null; then
                echo "   > Attempting to install nuclei via apt ..."
                apt-get update && apt-get install -y nuclei 2>/dev/null || true
            fi
            if ! command -v nuclei &>/dev/null; then
                echo "   > Attempting to install nuclei via wget ..."
                wget -qO- https://github.com/projectdiscovery/nuclei/releases/latest/download/nuclei_2.9.17_linux_amd64.zip | bsdtar -xvf- -C /usr/local/bin/ 2>/dev/null || true
                chmod +x /usr/local/bin/nuclei* 2>/dev/null || true
            fi
        # Special handling for amass (apt if go fails)
        elif [ "$tool" = "amass" ]; then
            go install github.com/owasp-amass/amass/v4/...@latest 2>/dev/null || apt-get update && apt-get install -y amass
        # General Go tools (try all common orgs)
        else
            go install "github.com/projectdiscovery/${tool}/v2/cmd/${tool}@latest" 2>/dev/null || \
            go install "github.com/tomnomnom/${tool}@latest" 2>/dev/null || \
            go install "github.com/lc/${tool}@latest" 2>/dev/null || \
            apt-get update && apt-get install -y "$tool" 2>/dev/null || true
        fi

        # Check again after all attempts
        if command -v "$tool" &>/dev/null; then
            echo "[✓] $tool installed successfully."
        else
            echo "   > Failed to install $tool, please install manually."
            if [[ -n "${TOOL_URLS[$tool]:-}" ]]; then
                echo "   > For install help: ${TOOL_URLS[$tool]}"
            fi
        fi
    else
        echo "[✓] $tool installed." | tee -a "$LOG"
    fi
done

for ptool in "${PYTHON_TOOLS[@]}"; do
    if ! python3 -c "import $ptool" &>/dev/null; then
        echo "[!] Python tool '$ptool' not found!"
        echo "   > Installing with: pip3 install $ptool"
        pip3 install $ptool
    else
        echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
    fi
done

echo "[*] Setup finished. Please review '$LOG' for any missing dependencies."
echo "   - For details, see the documentation or README.md."
