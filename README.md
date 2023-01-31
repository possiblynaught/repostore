# Repostore

Designed to backup and restore git repositories + local names of repos in a certain directory to/from a CSV file.

## Use

The scripts are designed to be inherited as a git submodule or used independently after exporting variables to point the scripts to the CSV file and target directory. Please see the sections below for inherited or standalone operation:

### Git submodule

You can use these scripts as a submodule in another repository. For instance, you could have a private repository to store your CSVs/configurations and point these scripts to your already saved configs. To add this project as a submodule, run this from within another repository:

```bash
git submodule add https://github.com/possiblynaught/repostore.git
```

Take a look at the *example\_submodule\_demo.sh* script for an example of integrating this into your existing automation/configuration. By exporting the *REPOSTORE\_REPO\_DIR* and *REPOSTORE\_CSV\_FILE* environment variables and calling *backup.sh* and *restore.sh*, you can automate the backup and restore process from another script.

### Standalone

The scripts can be used as standalone scripts by exporting environment variables to tell them where to look and store/load data from. Here are the values to export that are used by both the *backup.sh* and *restore.sh* scripts:

```bash
export REPOSTORE_REPO_DIR=/your/git/directory/
```

and

```bash
export REPOSTORE_CSV_FILE=/the/save/file.csv
```

After setting those variables, you can enter the *repostore* directory, make the scripts executable, and run them:

```bash
chmod +x backup.sh
./backup.sh
```

or

```bash
chmod +x restore.sh
./restore.sh
```

Once you are done, you can unset the variables until you need to run the scripts in the future:

```bash
unset REPOSTORE_REPO_DIR
unset REPOSTORE_CSV_FILE
```

You can also hard-code the directory/file paths within the scripts themselves, see the sections at the top of the scripts containing the text: *### Force override of environmental varables* to set persistent path variables to override any environmental variables.

## TODO

- [x] Add example submodule utilization script
- [x] Add better output formatting/spacing
- [x] Check for repo name collisions with different remote urls on restore
- [ ] Add description of CSV format to README
- [ ] Make restore clone multiple repos at once/parallel downloads
