#!/bin/bash

# Function to download the latest GitHub release based on given filters
download_github_release() {
    # Check if at least two arguments are provided
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <repository> <destination directory> [filter keywords...]"
        return 1
    fi

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

    # Find the asset download URLs from the release data based on the regex query
    local matching_urls=($(echo "$release_info" | jq -r --arg query "$query" '.assets[] | select(.name | test($query; "i")) | .browser_download_url'))

    print -c cyan $matching_urls

    if [ ${#matchingaUrls[@]} -eq 0 ]; then
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

    # Download the file
    local filename=$(basename "$asset_url")
    curl -L "$asset_url" -o "$dest/$filename"

    if [ $? -eq 0 ]; then
        echo "Downloaded $filename to $dest"
    else
        echo "Failed to download the file."
        return 1
    fi
}

# Example usage:
# download_github_release "sharkdp/bat" "/tmp/bat" "x86_64" "linux" "musl"


# If script is sourced, do nothing, only define function
# If script is run directly, call print_color with all command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_github_release "$@"
fi
