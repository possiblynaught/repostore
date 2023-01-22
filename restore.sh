#!/bin/bash

# Debug
#set -x
set -Eeo pipefail

### UNCOMMENT TO FORCE/OVERRIDE REPO DIR AND INPUT FILE ###
#OUTPUT_DIR="$HOME/Documents" # Directory to be searched for repos
#INPUT_FILE="/tmp/saved_repos.csv" # Output csv file

# Check if environmetal variables or overrides have been set, warn if missing
if [ -z "$OUTPUT_DIR" ]; then
  if [ -z "$REPOSTORE_REPO_DIR" ]; then
    echo "Error, please export the output/target directory location with: 
  export REPOSTORE_REPO_DIR=/dir/to/populate"
    exit 1
  else
    OUTPUT_DIR="$REPOSTORE_REPO_DIR"
  fi
fi
if [ -z "$INPUT_FILE" ]; then
  if [ -z "$REPOSTORE_CSV_FILE" ]; then
    echo "Error, please export the input csv file location with: 
  export REPOSTORE_CSV_FILE=/dir/input_file.csv"
    exit 1
  else
    INPUT_FILE="$REPOSTORE_CSV_FILE"
  fi
fi
# Add a backslash if needed
[[ "$OUTPUT_DIR" =~ '/'$ ]] || OUTPUT_DIR="$OUTPUT_DIR/"
# Create output folder and check for existence
mkdir -p "$OUTPUT_DIR"
[ -d "$OUTPUT_DIR" ] || (echo "Error, creating/finding output directory: $OUTPUT_DIR"; exit 1)
# Check for input file
[ -f "$INPUT_FILE" ] || (echo "Error, input csv file not found: $INPUT_FILE"; exit 1)
# Clone repos into the output dir if they don't already exist
COUNT=0
while read -r LINE; do
  NAME=$(echo "$LINE" | cut -d "," -f1)
  REPO="${OUTPUT_DIR}${NAME}"
  LINK=$(echo "$LINE" | cut -d "," -f2)
  if ! [ -d "$REPO" ]; then
    git clone ${LINK} ${REPO}
    COUNT=$((COUNT+1))
  fi
done < "$INPUT_FILE"
# Notify user of completion and status
echo "--------------------------------------------------------------------------------
Finished, cloned $COUNT new repos from $INPUT_FILE to output directory: $OUTPUT_DIR"
