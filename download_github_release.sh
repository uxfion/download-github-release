#!/bin/bash

# Function to download the latest GitHub release based on given filters
download_github_release() {
    local repo=$1
    local dest=$2
    local keywords=("$@") # Capture all parameters in an array

    # Remove the first two parameters as they are repo and dest
    keywords=("${keywords[@]:2}")

    local query=""

    # Build query string from remaining arguments for filtering the assets
    # Start the query with a term that ensures it's never empty and avoids leading +
    for keyword in "${keywords[@]}"; do
        # Append each keyword surrounded by wildcards to the query
        query="${query}(?=.*${keyword})"
    done

    # Use GitHub API to get the latest release data
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local release_info=$(curl -s "$api_url")

    # Find the asset download URL from the release data based on the regex query
    local asset_url=$(echo "$release_info" | jq -r --arg query "$query" '.assets[] | select(.name | test($query; "i")) | .browser_download_url')

    if [ -z "$asset_url" ]; then
        echo "Error: No asset found matching the criteria."
        return 1
    fi

    # Create destination directory if it does not exist
    mkdir -p "$dest"

    # Download the file
    local filename=$(basename "$asset_url")
    curl -L "$asset_url" -o "$dest/$filename"
    
    echo "Downloaded $filename to $dest"
}

# Example usage:
# download_github_release "sharkdp/bat" "/tmp/bat" "x86_64" "linux" "musl"

# If script is sourced, do nothing, only define function
# If script is run directly, call print_color with all command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_github_release "$@"
fi
