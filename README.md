# ![CoreX Banner](https://i.postimg.cc/wvPBrTff/banner-png.jpg)  

# CoreX 2025 | Bug Bounty Recon Toolkit  
Version: v1.0.1 – Stable release (July 2025)  

---

## 🛠️ What's New in v1.0.1 (Changelog)

- Added support for specifying a target or output folder manually in all scripts using -d / --dir / --target flags.
- Improved error handling: If no data is found in the target directory, a warning is shown ("No results found for this phase").
- Quick summary at the top of each report, including counts of live endpoints, high/critical vulns, XSS, etc.
- Phase-specific reporting: Generate a report for a specific phase using --phase option.
- Support for custom output file names/paths for reports.
- Enhanced FFUF module: If no wordlist is specified within 20 seconds, the default is used automatically.
- Highlighted high/critical vulnerabilities in terminal output.
- Enhanced interactive chaining: After each phase, prompt to continue or stop.
- Consistent serial numbering of output folders for each target.
- All scripts now maintain full compatibility with both standalone and pipeline modes.

---

## Overview  

CoreX is an automated, modular recon toolkit built specifically for Bug Bounty and security research. It supports full pipeline execution (passive → active → exploitation → reporting) or granular control to run individual tools or stages. All output is organized in structured directories per target.  

## Installation & Dependencies  

First, clone the repository:  
```bash  
git clone https://github.com/abdallah864/corex-recon.git  
cd corex-recon  
```  

Then Use the provided installer:  
```bash  
chmod +x install.sh  
./install.sh  
```  

It will check for required tools (Go + Python-based) and notify you of any missing dependencies in install_log.txt.  

### Tools Included:  
- Go Tools: subfinder, amass, assetfinder, httpx, nuclei, gf, dalfox, gau, waybackurls, ffuf, subjs  
- Python Tools: arjun, LinkFinder  

Failsafe Checks: If a tool is missing during execution of any script, the user is notified with a clear message and prompted to rerun the installer. This ensures robustness and reduces silent failures.  

---

## Manual Install Commands

If you prefer not to use the provided install.sh script, you can manually install all dependencies and tools with the following commands:

```bash
# Go (version 1.18 or above)
sudo apt update
sudo apt install -y golang

# Python3 and pip
sudo apt install -y python3 python3-pip

# Go-based tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/OWASP/Amass/v4/...@latest
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/tomnomnom/gf@latest
go install -v github.com/hahwul/dalfox/v2@latest
go install -v github.com/lc/gau/v2/cmd/gau@latest
go install -v github.com/tomnomnom/waybackurls@latest
go install -v github.com/tomnomnom/ffuf@latest
go install -v github.com/lc/subjs@latest

# Python-based tools
pip3 install arjun
git clone https://github.com/GerbenJavado/LinkFinder.git
cd LinkFinder && pip3 install -r requirements.txt && cd ..
```

> **Note:** Make sure `$GOPATH/bin` (usually `$HOME/go/bin`) is added to your PATH so you can run all Go tools directly from the terminal.

---

## Usage Options  

You can run the whole pipeline, or execute stages/scripts individually.  

### Run Full Pipeline:  
```bash  
chmod +x corex.sh  
./corex.sh all  
```  

### Run Individual Scripts:  
```bash  
./coreleak.sh       # Passive Recon  
./coreactive.sh     # Active Recon  
./coreexploit.sh    # Exploitation  
./coreport.sh       # Report Generator  
```  

### Run Specific Tool Inside a Script (Example):  
```bash  
./coreexploit.sh --dalfox-only      # Run Dalfox only  
./coreexploit.sh --ffuf-only        # Run FFUF only  
./coreexploit.sh --case-only        # Run case-sensitive scan only  
```  

### Global Options (for corex.sh):  
- --dry-run     Show commands without executing them  
- --verbose     Enable verbose output  
- --output-dir  Specify base output directory  
- --help        Show detailed help menu  

---

## Passive Recon (coreleak.sh)  

Performs enumeration, archive scraping, JS file discovery, param discovery, and sensitive keyword filtering.  

- Supports both root domains and subdomains. Automatically detects mode.  
- Optional Google Dork / GitDorker integration.  
- LinkFinder and Arjun used to extract endpoints and parameters.  
- Output saved in a versioned folder like coreleak_example.com_20250617_1  

### Sample Output Structure:  
- subs.txt — merged subdomains  
- js_urls.txt — JavaScript file URLs  
- urls_filtered.txt — filtered actionable URLs  
- arjun_params.txt, linkfinder_output.txt, etc.  

---

## Active Recon (coreactive.sh)  

Filters live hosts, fingerprinting, scans open ports, matches param patterns and more.  

- httpx is used for probing and tech detection  
- nmap scans ports/services on live IPs  
- nuclei scans for known CVEs and misconfigs  
- gf patterns detect potential XSS, LFI, SSRF endpoints  

### Example Output Files:  
- http_200.txt — endpoints with 200 OK  
- nuclei_report.txt — vulnerabilities found  
- gf_xss_hits.txt, gf_lfi_hits.txt — filtered patterns  

---

## Exploitation Phase (coreexploit.sh)  

- Aggregates parameters from gf, Arjun, and ParamSpider (if available)  
- Runs dalfox for XSS, ffuf for directory brute-forcing  
- Supports optional case-sensitive endpoint scanning  
- Optional nmap scan for vuln detection with --script vuln  

### Usage Examples:  
```bash  
./coreexploit.sh                     # Run all exploit tools  
./coreexploit.sh --ffuf-only        # Run FFUF only  
./coreexploit.sh --nmap-only        # Run only vuln scan with Nmap  
```  

### Output Samples:  
- dalfox_result.txt  
- ffuf_*.csv  
- case_scan/results_filtered.txt  
- nmap_vuln_scan.txt  

---

## Report Generator (coreport.sh)  

Creates both a summary.txt and structured summary.csv file containing:  
- Live endpoints  
- Vulnerabilities from Nuclei, Dalfox  
- GF pattern matches  
- FFUF brute-force findings  
- Manual findings + screenshots section  

CSV includes severity columns to filter in spreadsheets.  

---

## Output Directory Structure  
```
coreleak_target_YYYYMMDD_N/  
├── active/  
│   ├── http_200.txt  
│   ├── nuclei_report.txt  
│   └── ...  
├── exploit/  
│   ├── dalfox_result.txt  
│   ├── ffuf_*.csv  
│   └── case_scan/  
├── report/  
│   ├── summary.txt  
│   └── summary.csv  
├── subs.txt  
├── js_urls.txt  
└── ...  
```

---

## Smart Features  

- Auto Mode Detection: Automatically switches between domain/subdomain logic  
- Failsafe Tool Checks: Prevents silent failures by detecting missing tools and suggesting fixes  
- Tool-specific Execution: Run Dalfox/FFUF/etc separately  
- Output Isolation: Each run saved in timestamped, versioned folder  
- Interactive + Command Line Modes  

---

## Tools Used (Summary)  

| Tool        | Purpose                          |  
|-------------|----------------------------------|  
| subfinder   | Passive subdomain enumeration   |  
| amass       | Deep DNS subdomain enumeration  |  
| assetfinder | Asset discovery                 |  
| httpx       | HTTP probing & fingerprinting   |  
| nuclei      | Vulnerability scanning          |  
| gf          | Param pattern matching          |  
| arjun       | Hidden parameter discovery      |  
| dalfox      | XSS scanner                     |  
| ffuf        | Directory brute-forcing         |  
| gau         | Archived URLs via Wayback       |  
| subjs       | JS file extraction              |  
| nmap        | Port + vulnerability scan       |  

---

## Author  

Abdallah (corex2025)    
elshemy864@gmail.com  

---

## License  

Licensed under the MIT License. See the LICENSE file for full details.  

Author GitHub Profile: https://github.com/abdallah864
