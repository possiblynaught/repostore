# Repostore

Designed to backup and restore git repositories + local names of repos in a certain directory to/from a CSV file.

## Use

The scripts are designed to be inherited as a git submodule or used independently after exporting variables to point the scripts to the CSV file and target directory. Please see the sections below for inherited or standalone operation:

### Git submodule

You can use these scripts as a submodule in another repository. For instance, you could have a private repository to store your CSVs/configurations and point these scripts to your already saved configs. To add this repo as a submodule:

```console
# Add the repo as a submodule from within another repository:
git submodule add https://github.com/possiblynaught/repostore.git

# If you have already added it as a module and need to repopulate the
# submodule within a freshly cloned repo:
git submodule init
git submodule update
```

Take a look at the *example\_submodule\_demo.sh* script for an example of integrating this into your existing automation/configuration. By exporting the *REPOSTORE\_REPO\_DIR* and *REPOSTORE\_CSV\_FILE* environment variables and calling *backup.sh* and *restore.sh*, you can automate the backup and restore process from another script.

### Standalone

The scripts can be used as standalone scripts by exporting environment variables to tell them where to look and store/load data from. Here are the values to export:

```console
# Variables for the backup.sh and restore.sh scripts:
export REPOSTORE_REPO_DIR=/your/git/directory/
export REPOSTORE_CSV_FILE=/where/to/find/save/file.csv
```

After setting those variables, you can enter the *repostore* directory, make the scripts executable, and run them:

```console
# Download/clone repo and then enter it:
cd repostore/

# Backup:
chmod +x backup.sh
./backup.sh
# Restore:
chmod +x restore.sh
./restore.sh
```

Once you are done, you can unset the variables until you need to run the scripts in the future:

```console
# Unset variables when done
unset REPOSTORE_REPO_DIR
unset REPOSTORE_CSV_FILE
```

You can also hard-code the directory/file paths within the scripts themselves, see the sections at the top of the scripts containing the text: ***UNCOMMENT TO FORCE/OVERRIDE TRAVERSAL*** to set persistent path variables to override any environmental variables.

## TODO

- [x] Add example submodule utilization script
- [ ] Add description of CSV format to README
- [ ] Add better output formatting/spacing
- [ ] Check for repo name collisions with different remote urls on restore
