#!/bin/bash

# Global Variables
DOMAIN="$1"
OUTPUT_DIR="./$DOMAIN"
SUBDOMAINS_FILE="$OUTPUT_DIR/subdomains.txt"
LIVE_URLS_FILE="$OUTPUT_DIR/httprobe.txt"
JS_FILES="$OUTPUT_DIR/js_files.txt"
JSON_FILES="$OUTPUT_DIR/json_files.txt"
IMPORTANT_URLS="$OUTPUT_DIR/important_urls.txt"
THREADS=10
AMASS_RUN=0
AMASS_TIMEOUT=300

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
    printf "\nUsage: $0 <domain> [-t threads] [-a] [-m timeout]\n"
    printf "Options:\n"
    printf "  -t, --threads   Number of threads (default: 10)\n"
    printf "  -a, --amass     Run Amass for subdomain enumeration\n"
    printf "  -m, --timeout   Amass timeout in seconds (default: 300)\n"
    printf "  -h, --help      Show this help message\n"
    printf "\n"
}

# Function to perform subdomain enumeration
enumerate_subdomains() {
    local domain="$1"
    local temp_file="$OUTPUT_DIR/temp_subdomains.txt"

    printf "Enumerating subdomains...\n"

    # Run subdomain enumeration tools
    subfinder -d "$domain" -silent -t "$THREADS" >> "$temp_file" &
    assetfinder --subs-only "$domain" >> "$temp_file" &
    
    if [[ "$AMASS_RUN" -eq 1 ]]; then
        timeout "$AMASS_TIMEOUT" amass enum -passive -d "$domain" >> "$temp_file" &
    fi

    wait

    # Remove duplicates
    sort -u "$temp_file" | anew > "$SUBDOMAINS_FILE"
    rm "$temp_file"

    printf "Subdomain enumeration complete. Results saved to %s\n" "$SUBDOMAINS_FILE"
}

# Function to probe live URLs
probe_live_urls() {
    printf "Probing live URLs...\n"

    cat "$SUBDOMAINS_FILE" | httprobe -c "$THREADS" -prefer-https | anew > "$LIVE_URLS_FILE"

    printf "Live URLs saved to %s\n" "$LIVE_URLS_FILE"
}

# Function to fetch URLs from wayback and other sources
fetch_urls() {
    local temp_file="$OUTPUT_DIR/temp_urls.txt"

    printf "Fetching URLs from various sources...\n"

    cat "$LIVE_URLS_FILE" | waybackurls >> "$temp_file" &
    cat "$LIVE_URLS_FILE" | getallurls >> "$temp_file" &

    wait

    # Remove duplicates and save final URL list
    sort -u "$temp_file" | anew > "$OUTPUT_DIR/all_urls.txt"
    rm "$temp_file"

    printf "URL fetching complete. Results saved to %s\n" "$OUTPUT_DIR/all_urls.txt"
}

# Function to filter specific files and important URLs
filter_urls() {
    local urls_file="$OUTPUT_DIR/all_urls.txt"

    printf "Filtering URLs for .js, .json, and important keywords...\n"

    grep -iE '\.js(\?|$)' "$urls_file" | anew > "$JS_FILES"
    grep -iE '\.json(\?|$)' "$urls_file" | anew > "$JSON_FILES"
    grep -iE 'admin|auth|api|jenkins|corp|dev|stag|stg|prod|sandbox|swagger|aws|azure|uat|test|vpn|cms' "$urls_file" | anew > "$IMPORTANT_URLS"

    printf "Filtered JS files saved to %s\n" "$JS_FILES"
    printf "Filtered JSON files saved to %s\n" "$JSON_FILES"
    printf "Filtered important URLs saved to %s\n" "$IMPORTANT_URLS"
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
        -h|--help)
            usage
            exit 0
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

main() {
    if [[ -z "$DOMAIN" ]]; then
        usage >&2
        return 1
    fi

    enumerate_subdomains "$DOMAIN"
    probe_live_urls
    fetch_urls
    filter_urls
}

main "$@"

#
