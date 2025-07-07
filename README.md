# dobby
This Bash script automates the reconnaissance phase of bug bounty hunting by integrating several tools to discover subdomains, identify live domains, and extract URLs for further analysis. It is configurable, allowing adjustments for thread count, Amass usage, and timeouts. It is on its way to be upraded.

## Key Features

## Subdomain Enumeration:
Uses Subfinder, Assetfinder, and optionally Amass to discover subdomains.
Removes duplicates and stores results in subdomains.txt.

## Live Domain Probing:
Uses httprobe to identify responsive domains, saving results in httprobe.txt.

## URL Discovery:
Fetches historical and current URLs using Waybackurls and Getallurls, consolidating them in all_urls.txt.

## Filtering and Categorization:
Extracts JavaScript (js_files.txt) and JSON files (json_files.txt).
Filters URLs for sensitive keywords, storing them in important_urls.txt.

## How It Works
Input Domain: The user provides a domain, which determines the output directory.
Concurrency: Tools run in parallel where possible, using configurable thread counts.
Efficiency: Anew ensures all results are unique, preventing duplicates.
Keyword Filtering: Grep identifies URLs with potential security significance based on predefined keywords.

## Tools Used
Subfinder, Assetfinder, Amass (optional)
Httprobe
Waybackurls, Getallurls
Anew, Grep

## Usage
```
./dobby.sh <domain> [-t threads] [-a] [-m timeout]
Options:
  -t, --threads   Number of threads (default: 10)
  -a, --amass     Run Amass for subdomain enumeration
  -m, --timeout   Amass timeout in seconds (default: 300)
  -h, --help      Show this help message
```

![image](https://github.com/user-attachments/assets/d249c2d6-6a8b-4b2d-8b77-e6156c5b93f3)



## 🚀 Installation Guide

Follow these steps to install and set up **Dobby** on a Linux system:

```bash
git clone https://github.com/hellblack55/dobby
cd dobby
chmod +x setup.sh
./setup.sh
```
And you are all done!

## Verification
You can verify the installation by running the following commands:
```
bash
Copy code
subfinder -version
assetfinder -version
amass -version
httprobe -version
waybackurls -h
gau -h
anew -h
```

If these commands return the version or help output, the tools are installed correctly, and you're ready to run the script.
