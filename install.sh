#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Copyright (c) 2025 Abdallah (corex2025)
# This script is licensed under the MIT License. See LICENSE file for details.

echo "========================================"
echo "    CoreX - Auto Setup & Installer      "
echo "========================================"

# ===== إعداد الأدوات =====
REQUIRED_TOOLS=(subfinder amass assetfinder httpx nuclei gf dalfox ffuf gau waybackurls subjs nmap python3)
GO_TOOLS=(subfinder amass assetfinder httpx nuclei gf dalfox ffuf gau waybackurls subjs)
PYTHON_TOOLS=(arjun)

LOG="install_log.txt"
touch "$LOG"

# ===== دالة تثبيت Go =====
ensure_go() {
    if ! command -v go &>/dev/null; then
        echo "[!] Go not found! Installing Go 1.21.6 ..."
        wget -q https://go.dev/dl/go1.21.6.linux-amd64.tar.gz -O /tmp/go.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
    fi
    export PATH=$PATH:$(go env GOPATH)/bin
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
}

# ===== دالة تثبيت أداة Go =====
try_install_go() {
    case "$1" in
        subfinder)   go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest ;;
        amass)       go install github.com/owasp-amass/amass/v4/...@latest ;;
        assetfinder) go install github.com/tomnomnom/assetfinder@latest ;;
        httpx)       go install github.com/projectdiscovery/httpx/cmd/httpx@latest ;;
        nuclei)      go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest ;;
        gf)          go install github.com/tomnomnom/gf@latest ;;
        dalfox)      go install github.com/hahwul/dalfox/v2@latest ;;
        ffuf)        go install github.com/ffuf/ffuf@latest ;;
        gau)         go install github.com/lc/gau/v2/cmd/gau@latest ;;
        waybackurls) go install github.com/tomnomnom/waybackurls@latest ;;
        subjs)       go install github.com/lc/subjs@latest ;;
        *)           return 1 ;;
    esac
}

# ===== ابدأ =====
echo "[*] Checking required tools..."

ensure_go

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        echo "[!] $tool not found!"
        # إذا الأداة من أدوات Go
        if [[ " ${GO_TOOLS[@]} " =~ " $tool " ]]; then
            echo "   > Attempting to install $tool via Go ..."
            if try_install_go "$tool" &>/dev/null; then
                export PATH=$PATH:$(go env GOPATH)/bin
                hash -r
                if command -v "$tool" &>/dev/null; then
                    echo "[✓] $tool installed successfully." | tee -a "$LOG"
                else
                    echo "[!] $tool installation failed after Go install." | tee -a "$LOG"
                fi
            else
                echo "[!] Failed to install $tool, please install manually." | tee -a "$LOG"
            fi
        else
            echo "   > Please install $tool manually or check documentation." | tee -a "$LOG"
        fi
    else
        echo "[✓] $tool installed." | tee -a "$LOG"
    fi
done

for ptool in "${PYTHON_TOOLS[@]}"; do
    if ! python3 -c "import $ptool" &>/dev/null; then
        echo "[!] Python tool '$ptool' not found!"
        echo "   > Installing with: pip3 install $ptool"
        pip3 install "$ptool" || echo "[!] Failed to install $ptool, please install manually." | tee -a "$LOG"
    else
        echo "[✓] Python tool '$ptool' installed." | tee -a "$LOG"
    fi
done

echo "[*] Setup finished. Please review '$LOG' for any missing dependencies."
echo "   - For details, see the documentation or README.md."
