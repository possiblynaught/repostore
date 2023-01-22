#!/bin/bash

# Debug
#set -x
set -Eeuo pipefail

# Save script dir
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

################################################################################
# File to save/restore repositories to/from:
CSV_FILE="$SCRIPT_DIR/saved_repos.csv"
# Repository destination
REPO_DIR="$HOME/Documents"
################################################################################

# Check for repository directory
mkdir -p "$REPO_DIR"
[ -d "$REPO_DIR" ] || (echo "Error, directory not found: $REPO_DIR"; exit 1)

# Check for repostore submodule
REPOSTORE_SUBMODULE="$SCRIPT_DIR/repostore"
REPOSTORE_BACKUP="$REPOSTORE_SUBMODULE/backup.sh"
REPOSTORE_RESTORE="$REPOSTORE_SUBMODULE/restore.sh"
[ -d "$REPOSTORE_SUBMODULE" ] || (echo "Error, repostore submodule not found: $REPOSTORE_SUBMODULE"; exit 1)
[ -f "$REPOSTORE_BACKUP" ] && [ -f "$REPOSTORE_RESTORE" ] || (echo "Error, repostore script(s) not found in: $REPOSTORE_SUBMODULE"; exit 1)

# Export submodule variables
export REPOSTORE_CSV_FILE="$CSV_FILE"
export REPOSTORE_REPO_DIR="$REPO_DIR"

# Backup the repos using the backup script
${REPOSTORE_BACKUP}

# Unset submodule variables
unset REPOSTORE_CSV_FILE
unset REPOSTORE_REPO_DIR
