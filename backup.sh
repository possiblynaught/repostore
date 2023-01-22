#!/bin/bash

# Debug
#set -x
set -Eeuo pipefail

### UNCOMMENT TO FORCE/OVERRIDE TRAVERSAL DIR AND SAVE FILE ###
#SEARCH_DIR="$HOME/Documents" # Directory to be searched for repos
#OUTPUT_FILE="/tmp/saved_repos.csv" # Output csv file

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
# Check if environmetal variables or overrides have been set, warn if missing
if [ -z "$SEARCH_DIR" ]; then
  if [ -z "$REPOSTORE_SEARCH_DIR" ]; then
    echo "Error, please export the search directory location with: 
  export REPOSTORE_SEARCH_DIR=/dir/to/search"
    exit 1
  else
    SEARCH_DIR="$REPOSTORE_SEARCH_DIR"
  fi
fi
if [ -z "$OUTPUT_FILE" ]; then
  if [ -z "$REPOSTORE_OUTPUT_FILE" ]; then
    echo "Error, please export the output file location with: 
  export REPOSTORE_OUTPUT_FILE=/dir/output_file.csv"
    exit 1
  else
    OUTPUT_FILE="$REPOSTORE_OUTPUT_FILE"
  fi
fi
# Check that search directory exists and isn't empty
[ -d "$SEARCH_DIR" ] || (echo "Error, directory not found: $SEARCH_DIR"; exit 1)
[ "$(ls -A $SEARCH_DIR)" ] || (echo "Error, directory is empty: $SEARCH_DIR"; exit 1)
# Check for git repos and backup the dirs
for DIR in "$SEARCH_DIR"/*; do
  if [ -d "$DIR/.git/" ]; then
    cd "$DIR" || exit 1
    LINK=$(git config --get remote.origin.url)
    NAME="$(basename $DIR)"
    echo "$NAME,$LINK" >> "$OUTPUT_FILE"
  else
    echo "$DIR isn't a git repo, skipping"
  fi
done
# Sort output and remove duplicates
TEMP_FILE=$(mktemp /tmp/repostore.XXXXXX || exit 1)
sort "$OUTPUT_FILE" | uniq > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"
# Notify user of completion and save location
echo "--------------------------------------------------------------------------------
Finished, $(wc -l < $OUTPUT_FILE) repos are saved in: $OUTPUT_FILE"
