#!/bin/bash

# Function to download the latest GitHub release based on given filters
download_github_release() {
    # Display help message if help flag is detected or not enough arguments are provided
    if [[ "$1" == "-h" || "$1" == "--help" || "$#" -lt 2 ]]; then
        echo "Usage: $0 <repository> <destination directory> [filter keywords...]"
        echo "Download the latest GitHub release asset matching specified filters."
        echo ""
        echo "Arguments:"
        echo "  <repository>                 GitHub repository in the format 'owner/repo'"
        echo "  <destination directory>      Local directory to save the downloaded file"
        echo "  [filter keywords...]         Optional regular expression(s) to filter asset names"
        echo ""
        echo "Options:"
        echo "  -h, -- jhelp                   Display this help message and exit"
        echo ""
        echo "Examples:"
        echo "  $0 sharkdp/bat /tmp/bat linux.*musl     Download assets that match 'linux.*musl' in their name from sharkdp/bat"
        echo "  $0 sharkdp/bat /tmp/bat x86_64 linux   Download assets containing 'x86_64' and 'linux' in their name"
        return 0
    fi

    local repo=$1
    local dest=$2
    local keywords=("$@") # Capture all parameters in an array

    # Remove the first two parameters as they are repo and dest
    keywords=("${keywords[@]:2}")

    local query=""

    # Build regex pattern from remaining arguments for filtering the assets
    for keyword in "${keywords[@]}"; do
        # Append each keyword surrounded by wildcards to the query
        query="${query}(?=.*${keyword})"
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
# download_github_release sharkdp/bat /tmp/bat x86_64 linux musl


# If script is sourced, do nothing, only define function
# If script is run directly, call print_color with all command line arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    download_github_release "$@"
fi
