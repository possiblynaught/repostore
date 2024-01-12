# Repostore

Designed to backup and restore remote git repositories and their local name in a repositories directory using a CSV file.

## Info

Intended use:
```
a_directory_of_many_git_repos/
│
└───personal_config_repo/ (git repo you will use to backup/restore all others)
│   │   a_directory_of_many_git_repos.csv (file to backup/restore repos)
│   │   example_user_script.sh (your own script to trigger backup/restore subscripts)
│   │   ...
│   │
│   └───repostore/ (this repo added as a git submodule)
│       │   backup.sh
│       │   restore.sh
│       │   README.md
│   
└───...
```

This project is desinged to be added as a git submodule to a git repo that stores your repo CSVs. Add it to a repo with:

```bash
git submodule add https://github.com/possiblynaught/repostore.git
git submodule update --init --recursive
```

The *./repostore/backup.sh* script will backup all of your current remote git repos to a CSV, and the *./repostore/restore.sh* script will restore all remote repos from a CSV to your repos folder.

Both scripts can be run in one of four ways:
1. A specific CSV file passed to this script as an arg. Example: *./repostore/SCRIPT.sh "file.csv"*
2. An existing CSV file that matches the folder one directory up will allow the scripts to be called without args. Example: *all_repos.csv* in your personal repo that matches the name of the directory your personal repo is within *../all_repos/* allows you to just call *./repostore/SCRIPT.sh*
3. A file named *repostore.csv* in your personal repository allows the scripts to be called without args.
4. Two environment variables that point to the csv and the repositories directory can also be exported. Example: export *REPOSTORE_CSV_FILE* (points to csv file) and *REPOSTORE_REPO_DIR* (points to your directory full of git repos)

## Quickstart

Quickstart guide to store your collection of git repos to a personal github repo:

```bash
mkdir -p $HOME/Documents/git_repos && cd $HOME/Documents/git_repos
mkdir personal_conf && cd personal_conf
git init
touch "$(basename "$(dirname "$PWD")").csv"
git submodule add https://github.com/possiblynaught/repostore.git
git submodule update --init --recursive
./repostore/backup.sh
git add . && git commit -m "initial commit with repostore (github.com/possiblynaught/repostore)"
git remote add origin git@github.com:USERNAME/personal_conf.git
git push -u origin master
```

## Example User Script

Example user script to backup all your repos to your personal config repo:
```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1; pwd -P)"
################################################################################
# Specific file to save/restore repositories to/from:
CSV_FILE="$SCRIPT_DIR/specific_file.csv"
################################################################################
# Restore repos
run_scr="$SCRIPT_DIR/repostore/backup.sh"
cd "$SCRIPT_DIR" || exit 1
if [ ! -x "$run_scr" ]; then
  git submodule update --init --recursive
fi
"$run_scr" "$CSV_FILE"
git add "$CSV_FILE"
git commit && git push
```
