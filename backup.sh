#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

### Force override of environmental variables
#SEARCH_DIR="$HOME/Documents" # Directory to be searched for repos
#OUTPUT_FILE="/tmp/saved_repos.csv" # Output csv file

# Check if environmetal variable override has been set, also warn if missing var
if [ -z "$SEARCH_DIR" ]; then
  if [ -z "$REPOSTORE_REPO_DIR" ]; then
    echo "Error, please export the search directory location with: 
  export REPOSTORE_REPO_DIR=/dir/to/search"
    exit 1
  else
    SEARCH_DIR="$REPOSTORE_REPO_DIR"
  fi
fi
if [ -z "$OUTPUT_FILE" ]; then
  if [ -z "$REPOSTORE_CSV_FILE" ]; then
    echo "Error, please export the output file location with: 
  export REPOSTORE_CSV_FILE=/dir/output_file.csv"
    exit 1
  else
    OUTPUT_FILE="$REPOSTORE_CSV_FILE"
  fi
fi
# Add a backslash if needed
[[ "$SEARCH_DIR" =~ '/'$ ]] || SEARCH_DIR="$SEARCH_DIR/"
# Check that search directory exists and isn't empty
[ -d "$SEARCH_DIR" ] || (echo "Error, directory not found: $SEARCH_DIR"; exit 1)
[ "$(ls -A ${SEARCH_DIR})" ] || (echo "Error, directory is empty: $SEARCH_DIR"; exit 1)
# Check for git repos and backup the dirs
for DIR in "$SEARCH_DIR"*; do
  if [ -d "$DIR/.git/" ]; then
    cd "$DIR" || exit 1
    LINK=$(git config --get remote.origin.url || true)
    NAME="$(basename ${DIR})"
    if [ -n "$LINK" ] && [ -n "$NAME" ]; then
      echo "$NAME,$LINK" >> "$OUTPUT_FILE"
    else
      echo "$DIR appears to be a repo without a remote url, skipping"
    fi
  else
    echo "$DIR isn't a git repo, skipping"
  fi
done
# Sort output and remove duplicates
TEMP_FILE=$(mktemp /tmp/repostore.XXXXXX || exit 1)
sort "$OUTPUT_FILE" | uniq > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"
# Notify user of completion and save location
echo "
Searched $SEARCH_DIR for new repos, $(wc -l < ${OUTPUT_FILE}) repos are now saved in: $OUTPUT_FILE
"
