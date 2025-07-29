#!/bin/bash

# ==============================================================================
#
#                                 DOBBY v1.5
#
# A comprehensive, single-pass reconnaissance script for bug bounty hunting.
#
# ==============================================================================


# --- Global Variables & Defaults ---
THREADS=10
AMASS_RUN=0
RATE_LIMIT=0


# ==============================================================================
#
#                         SAFETY NET & FUNCTION DEFINITIONS
#
# ==============================================================================

# Cleanup function to kill all child processes on exit
cleanup() {
    printf "\n[!] Caught exit signal. Shutting down all child processes...\n"
    pkill -P $$ > /dev/null 2>&1
    printf "[✔] Cleanup complete. Exiting.\n"
    exit
}

# Trap command: Runs the 'cleanup' function on script EXIT, INTERRUPT (Ctrl+C), or TERMINATE signal.
trap cleanup EXIT INT TERM

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
    printf "  -a, --amass     Run Amass for deeper subdomain enumeration (can be slow)\n"
    printf "  -rl, --rate-limit Requests per second for httpx (default: none)\n"
    printf "  -h, --help      Show this help message\n"
    printf "\n"
}

# Function to perform subdomain enumeration on a single domain
enumerate_subdomains() {
    local domain="$1"
    local temp_results="$OUTPUT_DIR/temp_subdomains.txt"

    printf "[+] Starting subdomain enumeration for %s...\n" "$domain"

    # Run enumeration tools
    subfinder -d "$domain" -silent -t "$THREADS" >> "$temp_results" &
    assetfinder --subs-only "$domain" >> "$temp_results" &

    if [[ "$AMASS_RUN" -eq 1 ]]; then
        amass enum -passive -d "$domain" >> "$temp_results" &
    fi

    wait # Wait for all background jobs to finish

    # Process and save the final results
    sort -u "$temp_results" > "$SUBDOMAINS_FILE"
    rm "$temp_results"

    printf "[✔] Subdomain enumeration complete. Found %s unique subdomains. Saved to %s\n" "$(wc -l < "$SUBDOMAINS_FILE")" "$SUBDOMAINS_FILE"
}

# Function to probe live URLs
probe_live_urls() {
    printf "[+] Probing for live URLs with httpx...\n"
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
    touch "$ALL_URLS_FILE"
    if [[ ! -s "$LIVE_URLS_FILE" ]]; then
        printf "[!] No live URLs found to fetch from archives. Skipping.\n"
        return
    fi
    cat "$LIVE_URLS_FILE" | waybackurls >> "$ALL_URLS_FILE" &
    cat "$LIVE_URLS_FILE" | gau --threads "$THREADS" >> "$ALL_URLS_FILE" &
    wait
    sort -u -o "$ALL_URLS_FILE" "$ALL_URLS_FILE"
    printf "[✔] URL fetching complete. Found %s total URLs. Saved to %s\n" "$(wc -l < "$ALL_URLS_FILE")" "$ALL_URLS_FILE"
}

# Function to filter specific files and important URLs
filter_urls() {
    printf "[+] Filtering for interesting files and keywords...\n"
    if [[ ! -s "$ALL_URLS_FILE" ]]; then
        printf "[!] No URLs found to filter. Skipping.\n"
        return
    fi
    grep -iE '\.js(\?|$)' "$ALL_URLS_FILE" | anew > "$JS_FILES"
    grep -iE '\.json(\?|$)' "$ALL_URLS_FILE" | anew > "$JSON_FILES"
    grep -iE 'admin|auth|api|jenkins|corp|dev|stag|stg|prod|sandbox|swagger|aws|azure|uat|test|vpn|cms' "$ALL_URLS_FILE" | anew > "$IMPORTANT_URLS"
    printf "[✔] Filtering complete.\n"
    printf "  - Saved %s JS files to %s\n" "$(wc -l < "$JS_FILES")" "$JS_FILES"
    printf "  - Saved %s JSON files to %s\n" "$(wc -l < "$JSON_FILES")" "$JSON_FILES"
    printf "  - Saved %s important URLs to %s\n" "$(wc -l < "$IMPORTANT_URLS")" "$IMPORTANT_URLS"
}

# Main execution function
main() {
    enumerate_subdomains "$DOMAIN"
    probe_live_urls
    fetch_urls
    filter_urls
    printf "\n[🎉] Dobby has finished the scan for %s!\n" "$DOMAIN"
}


# ==============================================================================
#
#                               EXECUTION STARTS HERE
#
# ==============================================================================

# --- Parse Domain from arguments ---
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
if [[ $# -eq 0 ]] || [[ -z "$DOMAIN" ]]; then
    usage
    exit 1
fi

# --- Set File Paths now that DOMAIN is known ---
OUTPUT_DIR="./$DOMAIN"
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
LIVE_URLS_FILE="$OUTPUT_DIR/live_urls.txt"
ALL_URLS_FILE="$OUTPUT_DIR/all_urls.txt"
JS_FILES="$OUTPUT_DIR/js_files.txt"
JSON_FILES="$OUTPUT_DIR/json_files.txt"
IMPORTANT_URLS="$OUTPUT_DIR/important_urls.txt"

# Ensure the output directory exists
mkdir -p "$OUTPUT_DIR"

# --- Parse command-line flags ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threads) THREADS="$2"; shift 2 ;;
        -a|--amass) AMASS_RUN=1; shift ;;
        -rl|--rate-limit) RATE_LIMIT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

# --- Run the main function ---
main