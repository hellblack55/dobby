#!/bin/bash

# ==============================================================================
#
#                                 DOBBY v2.0
#
# A comprehensive, recursive reconnaissance script for bug bounty hunting.
#
# ==============================================================================


# --- Global Variables & Defaults ---
THREADS=10
AMASS_RUN=0
RATE_LIMIT=0
RECURSIVE_RUN=0
RECURSION_DEPTH=2 # Default depth if -r is used without -rd


# ==============================================================================
#
#                         SAFETY NET & FUNCTION DEFINITIONS
#
# ==============================================================================

# Cleanup function to kill all child processes on exit
cleanup() {
    printf "\n[!] Caught exit signal. Shutting down all child processes...\n"
    # The '-P $$' flag tells pkill to kill all processes whose parent is this script.
    # $$ is a special variable that holds the Process ID (PID) of the current script.
    pkill -P $$ > /dev/null 2>&1
    printf "[✔] Cleanup complete. Exiting.\n"
    exit
}

# Trap command: Sets up the safety net.
# It runs the 'cleanup' function on script EXIT, INTERRUPT (Ctrl+C), or TERMINATE signal.
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
    printf "  -r, --recursive Enable recursive subdomain enumeration\n"
    printf "  -rd, --recursion-depth Levels of recursion (default: 2)\n"
    printf "  -h, --help      Show this help message\n"
    printf "\n"
}

# Generic function to run enumeration tools on a list of domains
enumerate() {
    local input_file="$1"
    local output_file="$2"
    
    # Use -l flag for subfinder, which is more direct than a pipe.
    subfinder -l "$input_file" -silent -t "$THREADS" >> "$output_file" &
    
    while IFS= read -r domain; do
        assetfinder --subs-only "$domain" >> "$output_file" &
    done < "$input_file"

    if [[ "$AMASS_RUN" -eq 1 ]]; then
        while IFS= read -r domain; do
            amass enum -passive -d "$domain" >> "$output_file" &
        done < "$input_file"
    fi

    wait
}

# Function to handle the entire recursive enumeration process
run_recursive_enumeration() {
    local root_domain="$1"
    local master_list="$OUTPUT_DIR/master_subdomains.txt"
    local current_level_domains="$OUTPUT_DIR/level_0.txt"
    
    printf "[+] Starting enumeration for %s...\n" "$root_domain"
    echo "$root_domain" > "$master_list"
    echo "$root_domain" > "$current_level_domains"

    if [[ "$RECURSIVE_RUN" -eq 0 ]]; then
        # --- Standard non-recursive scan ---
        local temp_results="$OUTPUT_DIR/temp_results.txt"
        enumerate "$current_level_domains" "$temp_results"
        sort -u "$temp_results" | anew "$master_list"
        rm "$temp_results"
    else
        # --- Recursive scan ---
        printf "[i] Recursive mode enabled. Depth: %s levels.\n" "$RECURSION_DEPTH"
        for (( i=1; i<=RECURSION_DEPTH; i++ )); do
            printf "[+] Starting recursion level %s of %s...\n" "$i" "$RECURSION_DEPTH"
            local next_level_domains="$OUTPUT_DIR/level_$i.txt"
            local temp_results="$OUTPUT_DIR/temp_level_$i_results.txt"
            
            enumerate "$current_level_domains" "$temp_results"
            
            # Find only the brand new subdomains and save them for the next iteration
            sort -u "$temp_results" | anew "$master_list" | tee "$next_level_domains"
            
            # If no new subdomains were found, we can stop early
            if [[ ! -s "$next_level_domains" ]]; then
                printf "[i] No new subdomains found at this level. Halting recursion.\n"
                rm "$temp_results" "$next_level_domains" "$current_level_domains"
                break
            fi
            
            rm "$temp_results" "$current_level_domains"
            current_level_domains="$next_level_domains"
        done
        # Final cleanup of the last level file
        [[ -f "$current_level_domains" ]] && rm "$current_level_domains"
    fi
    
    # Copy the final master list to the main subdomains file
    cp "$master_list" "$SUBDOMAINS_FILE"
    rm "$master_list"
    
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
    run_recursive_enumeration "$DOMAIN"
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
# This is done first and calls the `usage` function which is now defined.
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
        -r|--recursive) RECURSIVE_RUN=1; shift ;;
        -rd|--recursion-depth) RECURSION_DEPTH="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) shift ;;
    esac
done

# --- Run the main function ---
main