# ![CoreX Banner](https://i.postimg.cc/wvPBrTff/banner-png.jpg)  

# CoreX 2025 | Bug Bounty Recon Toolkit  
🟢 Version: v1.0.0 – First official stable release (June 2025)

## 📌 Overview  

*CoreX* is an automated, modular recon toolkit built specifically for Bug Bounty and security research. It supports full pipeline execution (passive → active → exploitation → reporting) or granular control to run individual tools or stages. All output is organized in structured directories per target.  

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

It will check for required tools (Go + Python-based) and notify you of any missing dependencies in `install_log.txt`.  

### Tools Included:  
- *Go Tools*: subfinder, amass, assetfinder, httpx, nuclei, gf, dalfox, gau, waybackurls, ffuf, subjs  
- *Python Tools*: arjun, LinkFinder  

*Failsafe Checks*: If a tool is missing during execution of any script, the user is notified with a clear message and prompted to rerun the installer. This ensures robustness and reduces silent failures.  

## Usage Options  

You can run the whole pipeline, or execute stages/scripts individually.  

### Run Full Pipeline:  
```bash  
chmod +x corex.sh  
./corex.sh all  
```  

### Interactive Menu:  
```bash  
./corex.sh menu  
```  

### Run Individual Scripts:  
```bash  
./coreleak.sh       # Passive Recon  
./coreactive.sh     # Active Recon  
./coreexploit.sh    # Exploitation  
./corereport.sh     # Report Generator  
```  

### Run Specific Tool Inside a Script (Example):  
```bash  
./coreexploit.sh --dalfox-only      # Run Dalfox only  
./coreexploit.sh --ffuf-only        # Run FFUF only  
./coreexploit.sh --case-only        # Run case-sensitive scan only  
```  

### Global Options (for corex.sh):  
- `--dry-run`     Show commands without executing them  
- `--verbose`     Enable verbose output  
- `--output-dir`  Specify base output directory  

---

## Passive Recon (`coreleak.sh`)  

Performs enumeration, archive scraping, JS file discovery, param discovery, and sensitive keyword filtering.  

🔹 Supports both root domains and subdomains. Automatically detects mode.  
🔹 Optional Google Dork / GitDorker integration.  
🔹 LinkFinder and Arjun used to extract endpoints and parameters.  
🔹 Output saved in a versioned folder like `coreleak_example.com_20250617_1`  

### Sample Output Structure:  
- `subs.txt` — merged subdomains  
- `js_urls.txt` — JavaScript file URLs  
- `urls_filtered.txt` — filtered actionable URLs  
- `arjun_params.txt`, `linkfinder_output.txt`, etc.  

---

## Active Recon (`coreactive.sh`)  

Filters live hosts, fingerprinting, scans open ports, matches param patterns and more.  

🔹 `httpx` is used for probing and tech detection  
🔹 `nmap` scans ports/services on live IPs  
🔹 `nuclei` scans for known CVEs and misconfigs  
🔹 `gf` patterns detect potential XSS, LFI, SSRF endpoints  

### Example Output Files:  
- `http_200.txt` — endpoints with 200 OK  
- `nuclei_report.txt` — vulnerabilities found  
- `gf_xss_hits.txt`, `gf_lfi_hits.txt` — filtered patterns  

---

## Exploitation Phase (`coreexploit.sh`)  

🔹 Aggregates parameters from `gf`, `Arjun`, and `ParamSpider` (if available)  
🔹 Runs `dalfox` for XSS, `ffuf` for directory brute-forcing  
🔹 Supports optional *case-sensitive endpoint scanning*  
🔹 Optional `nmap` scan for vuln detection with `--script vuln`  

### Usage Examples:  
```bash  
./coreexploit.sh                     # Run all exploit tools  
./coreexploit.sh --ffuf-only        # Run FFUF only  
./coreexploit.sh --nmap-only        # Run only vuln scan with Nmap  
```  

### Output Samples:  
- `dalfox_result.txt`  
- `ffuf_*.csv`  
- `case_scan/results_filtered.txt`  
- `nmap_vuln_scan.txt`  

---

## 🧾 Report Generator (`corereport.sh`)  

Creates both a `summary.txt` and structured `summary.csv` file containing:  
- Live endpoints  
- Vulnerabilities from Nuclei, Dalfox  
- GF pattern matches  
- FFUF brute-force findings  
- Manual findings + screenshots section  

📎 CSV includes severity columns to filter in spreadsheets.  

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

✅ *Auto Mode Detection*: Automatically switches between domain/subdomain logic  
✅ *Failsafe Tool Checks*: Prevents silent failures by detecting missing tools and suggesting fixes  
✅ *Tool-specific Execution*: Run Dalfox/FFUF/etc separately  
✅ *Output Isolation*: Each run saved in timestamped, versioned folder  
✅ *Interactive + Command Line Modes*  

---

## 🧪 Real Target Demonstration  

While the default demo uses `openbugbounty.org`, *CoreX 2025* has also been tested on real-world bug bounty scopes.  

![active_result_sample](screenshots/indrive_results.png)  

It identifies live endpoints, extracts JS files, and fingerprints infrastructure (e.g. CloudFront, Envoy).  

---

## 🛠 Tools Used (Summary)  

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

## 📬 Author  

*Abdallah (corex2025)*    
📧 elshemy864@gmail.com  

---

## 🪪 License  

Licensed under the *MIT License*. See the [LICENSE](LICENSE) file for full details.  

---

🔗 *Author GitHub Profile:* [https://github.com/abdallah864](https://github.com/abdallah864)
