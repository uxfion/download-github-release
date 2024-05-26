#!/bin/bash

# Function to download the latest GitHub release based on given filters
download_github_release() {
    # Display help message if help flag is detected or not enough arguments are provided
    if [[ "$1" == "-h" || "$1" == "--help" || "$#" -lt 2 ]]; then
        echo "Usage: $0 <repository> <destination directory> [options] [filter keywords...]"
        echo "Download the latest GitHub release asset matching specified filters."
        echo ""
        echo "Arguments:"
        echo "  <repository>                 GitHub repository in the format 'owner/repo'"
        echo "  <destination directory>      Local directory to save the downloaded file"
        echo "  [filter keywords...]         Optional regular expression(s) to filter asset names"
        echo ""
        echo "Options:"
        echo "  -e, --exclude <pattern>  Exclude assets matching <pattern>"
        echo "  -m, --mirror                 Use GitHub mirror site for downloading"
        echo "  -h, --help                   Display this help message and exit"
        echo ""
        echo "Examples:"
        echo "  $0 sharkdp/bat /tmp/bat linux.*musl"
        echo "  $0 sharkdp/bat /tmp/bat linux x86 musl"
        echo "  $0 BurntSushi/ripgrep ./ linux x86"
        echo "  $0 BurntSushi/ripgrep ./ linux x86 -e sha256  # Exclude assets with 'sha256' in the name"
        echo "  $0 sxyazi/yazi ./ linux x86 -m  # Use mirror site for downloading"
        return 0
    fi

    local repo=$1
    local dest=$2
    shift 2
    local excludes=()
    local includes=()
    local use_mirror=false

    while (( "$#" )); do
        case "$1" in
            -e|--exclude)
                excludes+=("$2")  # Add to array of patterns to exclude
                shift 2
                ;;
            -m|--mirror)
                use_mirror=true  # Enable mirror site usage
                shift
                ;;
            *)
                includes+=("$1")  # Add to array of patterns to include
                shift
                ;;
        esac
    done

    # Construct the inclusion regex
    local query=""
    for keyword in "${includes[@]}"; do
        query="${query}(?=.*${keyword})"
    done

    # Add exclusion patterns
    for exclude in "${excludes[@]}"; do
        query="${query}(?!.*${exclude})"
    done

    # Use GitHub API to get the latest release data
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local release_info=$(curl -s "$api_url")

    # Find the asset download URLs from the release data based on the regex query
    local matching_urls=($(echo "$release_info" | jq -r --arg query "$query" '.assets[] | select(.name | test($query; "i")) | .browser_download_url'))

    if [ ${#matching_urls[@]} -eq 0 ]; then
        echo "Error: No asset found matching the criteria."
        return 1
    elif [ ${#matching_urls[@]} -gt 1 ]; then
        echo "Multiple assets found matching the criteria. Please specify additional keywords to narrow it down:"
        for url in "${matching_urls[@]}"; do
            echo "  - $url"
        done
        return 1
    fi

    # Only one URL should be here if the script reaches this point
    local asset_url=${matching_urls[0]}

    # Validate the asset URL
    if [[ ! "$asset_url" =~ ^https?:// ]]; then
        echo "Error: Retrieved URL is invalid: $asset_url"
        return 1
    fi

    # Create destination directory if it does not exist
    mkdir -p "$dest"
    if [ ! -d "$dest" ]; then
        echo "Error: Failed to create destination directory '$dest'"
        return 1
    fi

    # Function to download file and monitor speed
    download_with_speed_check() {
        local url=$1
        local dest_file=$2
        local log_file=$(mktemp)

        # Start download and monitor speed
        curl -L --progress-bar "$url" -o "$dest_file" 2> "$log_file" &
        local curl_pid=$!
        
        sleep 5  # Allow some time to gather initial speed data
        
        # Monitor speed
        while kill -0 $curl_pid 2> /dev/null; do
            local speed=$(tail -n 1 "$log_file" | grep -o '[0-9.]\+k' | sed 's/k//')
            if [[ -n "$speed" && $(echo "$speed < 10" | bc -l) -eq 1 ]]; then
                kill -9 $curl_pid 2> /dev/null
                return 1
            fi
            sleep 1
        done

        wait $curl_pid
        return $?
    }

    # Determine the initial URL to use
    local initial_url=$asset_url
    if $use_mirror; then
        initial_url="https://github.lecter.one/$asset_url"
    fi

    # Attempt download with initial URL
    local filename=$(basename "$initial_url")
    if ! download_with_speed_check "$initial_url" "$dest/$filename"; then
        # If the initial download fails or is too slow, and not using mirror, try mirror URL
        if ! $use_mirror; then
            echo "Download speed is too slow. Switching to mirror site."
            asset_url="https://github.lecter.one/$asset_url"
            if ! download_with_speed_check "$asset_url" "$dest/$filename"; then
                echo "Failed to download the file from both the original and mirror sites."
                return 1
            fi
        else
            echo "Failed to download the file from the mirror site."
            return 1
        fi
    fi

    echo "Downloaded $filename to $dest"
}

# If script is sourced, do nothing, only define function
# If script is run directly, call download_github_release with all command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_github_release "$@"
fi
