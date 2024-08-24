# dobby
This Bash script automates the reconnaissance phase of bug bounty hunting by integrating several tools to discover subdomains, identify live domains, and extract URLs for further analysis. It is configurable, allowing adjustments for thread count, Amass usage, and timeouts.

Key Features

Subdomain Enumeration:
Uses Subfinder, Assetfinder, and optionally Amass to discover subdomains.
Removes duplicates and stores results in subdomains.txt.

Live Domain Probing:
Uses httprobe to identify responsive domains, saving results in httprobe.txt.

URL Discovery:
Fetches historical and current URLs using Waybackurls and Getallurls, consolidating them in all_urls.txt.

Filtering and Categorization:
Extracts JavaScript (js_files.txt) and JSON files (json_files.txt).
Filters URLs for sensitive keywords, storing them in important_urls.txt.

How It Works
Input Domain: The user provides a domain, which determines the output directory.
Concurrency: Tools run in parallel where possible, using configurable thread counts.
Efficiency: Anew ensures all results are unique, preventing duplicates.
Keyword Filtering: Grep identifies URLs with potential security significance based on predefined keywords.

Tools Used
Subfinder, Assetfinder, Amass (optional)
Httprobe
Waybackurls, Getallurls
Anew, Grep
