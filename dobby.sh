#!/bin/bash

# Global Variables
# --- Set default values ---
THREADS=10
AMASS_RUN=0
AMASS_TIMEOUT=300
RATE_LIMIT=0 # Default: No rate limit. Set this to a number like 5 or 10 to slow down scans.

# --- Parse Domain from Arguments ---
# This ensures that even with flags, the first non-flag argument is the domain.
for arg in "$@"; do
  case $arg in
    -*) ;; # Ignore flags
    *)
      DOMAIN="$arg"
      break
      ;;
  esac
done

# --- Check if Domain is provided ---
if [[ -z "$DOMAIN" ]]; then
    echo "Error: Domain not provided."
    usage >&2
    exit 1
fi

# --- File Paths ---
OUTPUT_DIR="./$DOMAIN"
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
LIVE_URLS_FILE="$OUTPUT_DIR/live_urls.txt"
ALL_URLS_FILE="$OUTPUT_DIR/all_urls.txt"
JS_FILES="$OUTPUT_DIR/js_files.txt"
JSON_FILES="$OUTPUT_DIR/json_files.txt"
IMPORTANT_URLS="$OUTPUT_DIR/important_urls.txt"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# Function to display the usage and logo
usage() {
    printf "\n"
    printf "    _       _     _           \n"
    printf "    | |     | |   | |          \n"
    printf "  __| | ___ | |__ | |__  _   _ \n"
    printf " / _  |/ _ \\| '_ \\| '_ \\| | | |\n"
    printf "| (_| | (_) | |_) | |_) | |_| |\n"
    printf " \\____|\\___/|____/|____/ \\___ |\n"
    printf "                          __/ |\n"
    printf "                         |___/ \n"
    printf "\nUsage: $0 <domain> [options]\n"
    printf "Options:\n"
    printf "  -t, --threads   Number of threads (default: 10)\n"
    printf "  -a, --amass     Run Amass for deeper subdomain enumeration\n"
    printf "  -m, --timeout   Amass timeout in seconds (default: 300)\n"
    printf "  -rl, --rate-limit Requests per second for httpx (default: none)\n"
    printf "  -h, --help      Show this help message\n"
    printf "\n"
}

# Function to perform subdomain enumeration
enumerate_subdomains() {
    local domain="$1"
    local temp_file="$OUTPUT_DIR/temp_subdomains.txt"

    printf "[+] Enumerating subdomains for %s...\n" "$domain"

    # Run subdomain enumeration tools and append to a temporary file
    subfinder -d "$domain" -silent -t "$THREADS" >> "$temp_file" &
    assetfinder --subs-only "$domain" >> "$temp_file" &

    if [[ "$AMASS_RUN" -eq 1 ]]; then
        timeout "$AMASS_TIMEOUT" amass enum -passive -d "$domain" >> "$temp_file" &
    fi

    wait # Wait for all background jobs to finish

    # Sort and find unique subdomains, then save to the final file
    sort -u "$temp_file" > "$SUBDOMAINS_FILE"
    rm "$temp_file"

    printf "[✔] Subdomain enumeration complete. Found %s unique subdomains. Saved to %s\n" "$(wc -l < "$SUBDOMAINS_FILE")" "$SUBDOMAINS_FILE"
}

# Function to probe live URLs
probe_live_urls() {
    printf "[+] Probing for live URLs with httpx...\n"

    # Build the httpx command
    local httpx_cmd="httpx -threads $THREADS -silent"
    if [[ "$RATE_LIMIT" -gt 0 ]]; then
        httpx_cmd="$httpx_cmd -rate-limit $RATE_LIMIT"
        printf "[i] Rate limit set to %s requests/second.\n" "$RATE_LIMIT"
    fi

    cat "$SUBDOMAINS_FILE" | $httpx_cmd > "$LIVE_URLS_FILE"

    printf "[✔] Probing complete. Found %s live URLs. Saved to %s\n" "$(wc -l < "$LIVE_URLS_FILE")" "$LIVE_URLS_FILE"
}

# Function to fetch URLs from archives
fetch_urls() {
    printf "[+] Fetching URLs from archives (Wayback and GAU)...\n"
    touch "$ALL_URLS_FILE" # Ensure file exists even if sources find nothing

    cat "$LIVE_URLS_FILE" | waybackurls >> "$ALL_URLS_FILE" &
    cat "$LIVE_URLS_FILE" | gau --threads "$THREADS" >> "$ALL_URLS_FILE" &

    wait

    # De-duplicate the final list in-place
    sort -u -o "$ALL_URLS_FILE" "$ALL_URLS_FILE"

    printf "[✔] URL fetching complete. Found %s total URLs. Saved to %s\n" "$(wc -l < "$ALL_URLS_FILE")" "$ALL_URLS_FILE"
}

# Function to filter specific files and important URLs
filter_urls() {
    printf "[+] Filtering for interesting files and keywords...\n"

    grep -iE '\.js(\?|$)' "$ALL_URLS_FILE" | anew > "$JS_FILES"
    grep -iE '\.json(\?|$)' "$ALL_URLS_FILE" | anew > "$JSON_FILES"
    grep -iE 'admin|auth|api|jenkins|corp|dev|stag|stg|prod|sandbox|swagger|aws|azure|uat|test|vpn|cms' "$ALL_URLS_FILE" | anew > "$IMPORTANT_URLS"

    printf "[✔] Filtering complete.\n"
    printf "  - Saved %s JS files to %s\n" "$(wc -l < "$JS_FILES")" "$JS_FILES"
    printf "  - Saved %s JSON files to %s\n" "$(wc -l < "$JSON_FILES")" "$JSON_FILES"
    printf "  - Saved %s important URLs to %s\n" "$(wc -l < "$IMPORTANT_URLS")" "$IMPORTANT_URLS"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threads)
            THREADS="$2"
            shift 2
            ;;
        -a|--amass)
            AMASS_RUN=1
            shift
            ;;
        -m|--timeout)
            AMASS_TIMEOUT="$2"
            shift 2
            ;;
        -rl|--rate-limit)
            RATE_LIMIT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            shift # Shift past the domain, which is already captured
            ;;
    esac
done

# --- Main execution flow ---
main() {
    enumerate_subdomains "$DOMAIN"
    probe_live_urls
    fetch_urls
    filter_urls
    printf "\n[🎉] Dobby has finished the scan for %s!\n" "$DOMAIN"
}

# Run the main function
main