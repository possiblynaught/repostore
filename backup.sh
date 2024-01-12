#!/usr/bin/env bash
# Script to backup git repositories from a local directory to a CSV file.
# It will automatically try these options in this order:
# 1) A CSV file passed to this script:
#      Example: ./repostore/restore.sh "file.csv"
# 2) A CSV file one directory up matching the folder two directories up:
#      Example: '../repositories.csv' and '../../repositories/'
# 3) A 'repostore.csv' file one directory up:
#      Example: '../repostore.csv'
# 4) Two environment vars that point to the csv and the repositories directory:
#      'REPOSTORE_CSV_FILE' and 'REPOSTORE_REPO_DIR'

# Env vars
set -Eeo pipefail
# Debug
[[ "${DEBUG:-0}" == "1" ]] && set -x

# Script variables
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
host_dir="$(dirname "$SCRIPT_DIR")"
REPOS_DIR="$(dirname "$host_dir")"
temp_partial="$host_dir/$(basename "$REPOS_DIR")"
hardcoded="$host_dir/repostore.csv"
start_time="$(date +%s)"
non_repos=""

# Error handler
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

# Main
main () {
  # Check to make sure script is a submodule
  if [ ! -f "$SCRIPT_DIR/.git" ]; then
    err "Error, script was designed to be run as a submodule within another repo: $0
    No submodule detected, add this as a submodule in a repo with:
      git submodule add https://github.com/possiblynaught/repostore.git
      git submodule update --init --recursive"
  elif [ ! -d "$host_dir/.git" ]; then
    err "Error, script was designed to be run as a submodule within another repo: $0
    No 'host' git repo detected in:
      $host_dir"
  fi
  
  # Look for CSV files
  if [ -f "$1" ]; then
    CSV_FILE="$1"
  elif [ -f "$temp_partial.csv" ]; then
    CSV_FILE="$temp_partial.csv"
  elif [ -f "$temp_partial.CSV" ]; then
    CSV_FILE="$temp_partial.CSV"
  elif [ -f "$hardcoded" ]; then
    CSV_FILE="$hardcoded"
  elif [ -f "$REPOSTORE_CSV_FILE" ] && [ -d "$REPOSTORE_REPO_DIR" ]; then
    CSV_FILE="$REPOSTORE_CSV_FILE"
    REPOS_DIR="$REPOSTORE_REPO_DIR"
  else
    err "Error, unable to find a populated CSV file to use in: $0
  Expected one of the following:
  - A CSV passed to this script directly:
    $0 \"$host_dir/jeff.csv\"
  - A CSV file named after the repos directory two levels up:
    $temp_partial.csv
  - A '$(basename "$hardcoded")' file one directory up:
    $hardcoded
  - Two environment vars that point to the csv and the repositories dir:
    'REPOSTORE_CSV_FILE' and 'REPOSTORE_REPO_DIR'"
  fi

  # Sort and de-duplicate csv, store to temporary file
  temp_csv="$(mktemp || err "Error, unable to create a tempfile in $0")"
  sort < "$CSV_FILE" | uniq > "$temp_csv"
  starting_repos="$(wc -l < "$temp_csv")"
  
  # Check for valid repository directory and notify on non-repositories
  start_dir="$PWD"
  for dir in "$REPOS_DIR"/*; do
    if [ -f "$dir" ]; then
      echo "Warning, non-directory found: $dir"
    elif [ ! -d "$dir/.git" ]; then
      if [ ! -f "$non_repos" ]; then
        non_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
      fi
      echo "$dir" >> "$non_repos"
    else
      cd "$dir" || err "Error, unable to enter directory: $dir"
      echo "$(basename "$dir"),$(git config --get remote.origin.url)" >> "$temp_csv"
    fi
  done
  cd "$start_dir" || err "Error, unable to enter directory: $start_dir"

  # Sort and filter
  mv "$CSV_FILE" "$CSV_FILE.old"
  sort < "$temp_csv" | uniq > "$CSV_FILE"

  # Warn of non-repos
  if [ -s "$non_repos" ]; then
    echo -e "\n###############################################################################"
    sed 's|.*/||' < "$non_repos"
    echo "-------------------------------------------------------------------------------"
    echo "Warning, $(wc -l < "$non_repos") non-git repo(s) in: $REPOS_DIR"
    echo -e "  The non-repos have been stored to: $non_repos\n"
  else
    rm -f "$non_repos"
  fi

  # Warn of duplicate remote links in input file
  temp_duplicate="$(mktemp || err "Error, unable to create a tempfile in $0")"
  cut -d "," -f2 < "$CSV_FILE" | sort | uniq -i -D | uniq -c | awk '{$1=$1};1' > "$temp_duplicate"
  if [ -s "$temp_duplicate" ]; then
    duplicate_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
    echo -e "\n###############################################################################"
    while read -r line; do
      temp_num="$(echo "$line" | cut -d " " -f1)"
      temp_link="$(echo "$line" | cut -d " " -f2)"
      echo "Found $temp_num repos with the same remote link:"
      echo "  Repos: $(grep -iF "$temp_link" < "$CSV_FILE" | cut -d "," -f1 | tr '\n' ' ')"
      echo "  Link: $temp_link"
      echo "$temp_num,$temp_link,$(grep -iF "$temp_link" < "$CSV_FILE" | cut -d "," -f1 | tr '\n' ' ')" >> "$duplicate_repos"
    done < "$temp_duplicate"
    echo "-------------------------------------------------------------------------------"
    echo "Warning: Found $(wc -l < "$duplicate_repos") duplicate repo(s) above in: $CSV_FILE"
    echo -e "  Info on the duplicates has been saved to: $duplicate_repos\n"
  fi
  rm -f "$temp_duplicate"

  # Notify of completion
  echo -e "\n-------------------------------------------------------------------------------"
  total_added=$(( "$(sort < "$CSV_FILE" | uniq | wc -l)" - starting_repos ))
  if [[ "$total_added" -gt 0 ]]; then
    echo "Successfully added $total_added new repo(s) to the list!"
  else
    echo "No new repos to add to the list, skipping..."
  fi
  echo "  - Source: $(( $(find "$REPOS_DIR" -maxdepth 1 -type d | wc -l) - 1 )) folder(s) in $REPOS_DIR"
  echo "  - Destination: $(wc -l < "$CSV_FILE") repo(s) in $CSV_FILE"
  echo "  - Duration: $(( "$(date +%s)" - start_time )) seconds"

  # Delete temp files
  rm -f "$temp_csv"
}

# TODO: Handle multiple repository folders/csv files?
# Run main
main "$@"
