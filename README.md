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



## Installation Guide

```
git clone https://github.com/hellblack55/dobby
```

To run the script, you'll need to install several tools. Follow the steps below to install each tool on a Linux system.

### 1. Install Go (if not already installed)
Most of these tools are written in Go, so you'll need it installed on your system.

```bash
sudo apt update
sudo apt install -y golang
```

Add Go binaries to your PATH if you haven't done so:
```
export PATH=$PATH:/usr/local/go/bin
```

## 2. Install Subfinder
Subfinder is a subdomain discovery tool.

```
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

## 3. Install Assetfinder
Assetfinder is another tool for finding subdomains.
```
go install github.com/tomnomnom/assetfinder@latest
```

## 4. Install Amass (optional)
Amass is a powerful tool for in-depth subdomain enumeration.
```
sudo apt install -y amass
```

## 5. Install Httprobe
Httprobe helps you find live hosts among your discovered subdomains.
```
go install github.com/tomnomnom/httprobe@latest
```

## 6. Install Waybackurls
Waybackurls fetches URLs from the Wayback Machine.
```
go install github.com/tomnomnom/waybackurls@latest
```

## 7. Install Getallurls (GAU)
GAU fetches URLs from multiple sources.
```
go install github.com/lc/gau/v2/cmd/gau@latest
```

## 8. Install Anew
Anew ensures only unique lines are appended to your files.
```
go install github.com/tomnomnom/anew@latest
```

## 9. Install Grep
Grep is a standard tool for searching text using patterns. It's usually pre-installed on most Linux distributions.
```
sudo apt install -y grep
```

## Final Setup
After installing all the tools, ensure your environment variables are set correctly:
```
export PATH=$PATH:$(go env GOPATH)/bin
```

You can add the above line to your .bashrc or .zshrc file to make it permanent:
```
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc
```

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
