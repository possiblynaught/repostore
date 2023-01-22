#!/usr/bin/env bash
# Script to restore git repositories from a CSV file to a local directory.
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

# Function + while loop variables
MAX_CLONE_CONCURRENT=5 # Number of concurrent git clone operations to perform
MAX_CLONE_RETRY=3 # Number of times to retry a repo clone if it fails
MAX_CLONE_TIMEOUT=3600 # Seconds to run before failing on no progress cloning
fail_time=$(( "$(date +%s)" + MAX_CLONE_TIMEOUT ))
failed_repos=""
successful_repos=""
clone_repos=""
exist_repos=""
non_repos=""

# Error handler
err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
  exit 1
}

# Function to add a repo to the failed repo file
# Pass a csv line and (optionally) an retry number
add_fail() {
  if [ -z "$1" ]; then
    err "Error, no failed csv line (arg 1) passed to: $0"
  elif [ ! -f "$failed_repos" ]; then
    failed_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
  fi
  if [ -z "$2" ]; then
    echo "$1" >> "$failed_repos"
  else
    echo "$1,$2" >> "$failed_repos"
  fi
}

# Function to add a repo to the clone queue file
# Pass a destination path, remote link, and (optionally) an retry number
add_clone() {
  if [ -z "$1" ]; then
    err "Error, no repo destination path (arg 1) passed to: $0"
  elif [ -d "$1" ]; then
    err "Error, repo destination passed to $0 isn't empty:
  $1"
  elif [ -z "$2" ]; then
    err "Error, no remote repo link (arg 2) passed to: $0"
  elif [ ! -f "$clone_repos" ]; then
    clone_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
  fi
  if [ -z "$3" ]; then
    echo "$1,$2,0" >> "$clone_repos"
  else
    echo "$1,$2,$3" >> "$clone_repos"
  fi
}

# Function to check if existing folder has a different git source
# Pass a destination path and remote link
check_collision() {
  if [ -z "$1" ]; then
    err "Error, no repo destination path (arg 1) passed to: $0"
  elif [ ! -d "$1" ]; then
    err "Error, repo destination passed to $0 isn't empty:
  $1"
  elif [ -z "$2" ]; then
    err "Error, no remote repo link (arg 2) passed to: $0"
  fi
  local temp_dir
  temp_dir="$PWD"
  cd "$1" || err "Error, unable to enter directory: $1"
  if [[ "$(git config --get remote.origin.url)" != "$2" ]]; then
    echo "Warning, repo collision detected for: $(basename "$1")"
    if [ ! -f "$exist_repos" ]; then
      exist_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
    fi
    echo "$(basename "$1"),$2" >> "$exist_repos"
  fi
  cd "$temp_dir" || err "Error, unable to enter directory: $temp_dir"
}

# Function to clone a new repo into the destination folder
# Pass a destination path, a repo link, and (optionally) an retry number
clone_repo() {
  local retry
  if [ -z "$1" ]; then
    err "Error, no repo destination path (arg 1) passed to: $0"
  elif [ -z "$2" ]; then
    err "Error, no remote repo link (arg 2) passed to: $0"
  elif [ -d "$1" ]; then
    echo "Error, repo destination passed to $0 isn't empty:
  $1"
    add_fail "$1,$2"
    return
  elif [ -n "$3" ]; then
    retry="$(echo "$3" | tr -dc "[:digit:]")"
  fi
  if [ -z "$retry" ] || [[ "$retry" -eq 0 ]]; then
    retry=1
    echo "Cloning into repo: $(basename "$1")"
  elif [[ "$retry" -ge "$MAX_CLONE_RETRY" ]]; then
    echo "Clone has failed $retry times for repo: $(basename "$1")"
    add_fail "$1,$2" "$retry"
    return
  else 
    retry=$(( retry + 1 ))
    echo "(Try $retry/$MAX_CLONE_RETRY) Cloning into repo: $(basename "$1")"
  fi
  if ! git clone "$2" "$1" &> /dev/null; then
    echo "Error during clone, retrying soon for repo: $(basename "$1")"
    rm -rf "$1"
    add_clone "$1" "$2" "$retry"
  else
    echo "$1" >> "$successful_repos"
  fi
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
  if [ -s "$1" ]; then
    csv_file="$1"
  elif [ -s "$temp_partial.csv" ]; then
    csv_file="$temp_partial.csv"
  elif [ -s "$temp_partial.CSV" ]; then
    csv_file="$temp_partial.CSV"
  elif [ -s "$hardcoded" ]; then
    csv_file="$hardcoded"
  elif [ -s "$REPOSTORE_CSV_FILE" ] && [ -d "$REPOSTORE_REPO_DIR" ]; then
    csv_file="$REPOSTORE_CSV_FILE"
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
  CSV_FILE="$(mktemp || err "Error, unable to create a tempfile in $0")"
  sort < "$csv_file" | uniq > "$CSV_FILE"
  if [ ! -s "$CSV_FILE" ]; then
    rm -f "$CSV_FILE"
    err "Error, it appears there are no repos in the csv file: $csv_file"
  fi
  
  # Check for valid repository directory and notify on non-repositories
  for dir in "$REPOS_DIR"/*; do
    if [ -f "$dir" ]; then
      echo "Warning, non-directory found: $dir"
    elif [ ! -d "$dir/.git" ]; then
      if [ ! -f "$non_repos" ]; then
        non_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
      fi
      echo "$dir" >> "$non_repos"
    fi
  done
  if [ -s "$non_repos" ]; then
    echo -e "\n-------------------------------------------------------------------------------"
    sed 's|.*/||' < "$non_repos"
    echo "-------------------------------------------------------------------------------
    The $(wc -l < "$non_repos") directories above are in: $REPOS_DIR"
    read -n 1 -s -r -p "These are not git repos, if that is acceptable, press any key to proceed anyway: "
    echo "Proceeding, the non-repos have been stored to: $non_repos"
  else
    rm -f "$non_repos"
  fi

  # Loop through stored repos and prep execution queue files
  echo "Comparing repository directory with stored repos..."
  while read -r repo; do
    repo_name="$(echo "$repo" | cut -d "," -f1)"
    repo_path="$REPOS_DIR/$repo_name"
    repo_link="$(echo "$repo" | cut -d "," -f2)"
    if [ -z "$repo_name" ] || [ -z "$repo_link" ]; then
      add_fail "$repo"
    elif [ ! -d "$repo_path" ]; then
      add_clone "$repo_path" "$repo_link"
    elif [ -d "$repo_path/.git" ]; then
      check_collision "$repo_path" "$repo_link"
    fi
  done < "$CSV_FILE"

  # Start cloning new repos in parallel
  if [ -s "$clone_repos" ]; then
    echo "Cloning $(wc -l < "$clone_repos") new repos to: $REPOS_DIR/"
    successful_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
    while read -r repo; do
      repo_path="$(echo "$repo" | cut -d "," -f1)"
      repo_link="$(echo "$repo" | cut -d "," -f2)"
      repo_try="$(echo "$repo" | cut -d "," -f3 | tr -dc "[:digit:]")"
      # Busy wait for parallelization
      while [[ "$(jobs | wc -l)" -gt "$MAX_CLONE_CONCURRENT" ]]; do
        sleep 1
        if [[ "$(date +%s)" -ge "$fail_time" ]]; then
          err "Error, hit MAX_CLONE_TIMEOUT of $MAX_CLONE_TIMEOUT seconds in $0"
        fi
      done
      fail_time=$(( "$(date +%s)" + MAX_CLONE_TIMEOUT ))
      clone_repo "$repo_path" "$repo_link" "$repo_try" &
    done < "$clone_repos"
  fi

  # Warn of repo name collisions with different remote links
  # TODO: Auto-rename and clone name collsions with diff links?
  if [ -s "$exist_repos" ]; then
    echo -e "\n###############################################################################"
    cut -d "," -f1 < "$exist_repos"
    echo "-------------------------------------------------------------------------------"
    echo "Warning: Failed to clone the $(wc -l < "$exist_repos") repo(s) above!"
    echo "  The repos already exit with different remote link"
    echo -e "  These existing repo collisions have been saved in csv format to: $exist_repos\n"
  else
    rm -f "$exist_repos"
  fi

  # Warn of duplicate remote links in input file
  temp_duplicate="$(mktemp || err "Error, unable to create a tempfile in $0")"
  cut -d "," -f2 < "$csv_file" | sort | uniq -i -D | uniq -c | awk '{$1=$1};1' > "$temp_duplicate"
  if [ -s "$temp_duplicate" ]; then
    duplicate_repos="$(mktemp || err "Error, unable to create a tempfile in $0")"
    echo -e "\n###############################################################################"
    while read -r line; do
      temp_num="$(echo "$line" | cut -d " " -f1)"
      temp_link="$(echo "$line" | cut -d " " -f2)"
      echo "Found $temp_num duplicate repos with the same remote link:"
      echo "  Repos: $(grep -iF "$temp_link" < "$csv_file" | cut -d "," -f1 | tr '\n' ' ')"
      echo "  Link: $temp_link"
      echo "$temp_num,$temp_link,$(grep -iF "$temp_link" < "$csv_file" | cut -d "," -f1 | tr '\n' ' ')" >> "$duplicate_repos"
    done < "$temp_duplicate"
    echo "-------------------------------------------------------------------------------"
    echo "Warning: Found $(wc -l < "$duplicate_repos") duplicate repo(s) above in: $csv_file"
    echo -e "  Info on the duplicates has been saved to: $duplicate_repos\n"
  fi
  rm -f "$temp_duplicate"

  # Warn of any failed repos
  if [ -s "$failed_repos" ]; then
    echo -e "\n###############################################################################"
    cut -d "," -f1 < "$failed_repos"
    while read -r line; do
      temp_num="$(echo "$line" | cut -d "," -f3 | tr -dc "[:digit:]")"
      if [[ "$temp_num" -ge "$MAX_CLONE_RETRY" ]]; then
        echo "Failed to clone repo: $(echo "$line" | cut -d "," -f1)"
        echo "  $(echo "$line" | cut -d "," -f2)"
      else
        echo "Unknown error for the line:"
        echo "  $line"
      fi
    done < "$failed_repos"
    echo "-------------------------------------------------------------------------------"
    echo "Warning: Had $(wc -l < "$failed_repos") failed repo(s) above in: $csv_file"
    echo -e "  Failed list in CSV format saved to: $failed_repos\n"
  else
    rm -f "$failed_repos"
  fi

  # Notify of completion
  echo -e "\n-------------------------------------------------------------------------------"
  if [ ! -f "$successful_repos" ]; then
    echo "Nothing to do, repo directory is up to date!"
  else
    echo "Successfully restored $(wc -l < "$successful_repos") missing repo(s)!"
  fi
  echo "  - Source: $(wc -l < "$CSV_FILE") repo(s) in $csv_file"
  echo "  - Destination: $(( $(find "$REPOS_DIR" -maxdepth 1 -type d | wc -l) - 1 )) folder(s) in $REPOS_DIR"
  echo "  - Duration: $(( "$(date +%s)" - start_time )) seconds"

  # Delete temp files
  rm -f "$CSV_FILE"
  rm -f "$clone_repos"
  rm -f "$successful_repos"
}

# TODO: Handle multiple repository folders/csv files?
# Run main
main "$@"
