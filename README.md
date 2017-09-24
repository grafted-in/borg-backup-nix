# Borg Backup Nix Module

These Nix modules provide a convenient method to use [Borg backup](https://borgbackup.readthedocs.io/en/stable/) as a tool for storing periodic backups on a remote server via SSH. The backups are encrypted, deduplicated, and compressed.

## Provisioning

You can provision a deployed server which will generate an SSH key pair for it to use when connecting to the remote backup server. Run `./provision-backup-auth` (see source for expected arguments) to provision a server with SSH keys.

The provision script is designed to work with this [nixops-manager](https://github.com/grafted-in/nixops-manager) and it expects the manager to be at `<repo>/deploy/manage`. Be sure to run it from within the same git repo that houses your server configuration.

## Configuration

Use `backup-repo.keys.nix.sample` as an example way to store the backup keys in a separate file which can be encrypted (with `git-crypt` for example).

By default the backup system will run once per day. You can run it at any time by logging in as the backup user (e.g. `su - backup`) and running `run-backup`.

Refer to the module's options for information regarding the service configuration.

## Installation

Install the module by adding `module-borg-backup.nix` to the list of `imports` in your configuration.

## Restoring a backup

A script called `use-borg-repo` is deployed to the server which wraps the `borg` calls and uses the database as configured by the deployment. You can use that script directly by SSHing into the server and loggig in as the backup user (e.g. `su - backup`).

To use the script locally you can:

  * If you're on Linux, you can make an innocuous change to `mk-use-borg-repo.nix` and run `nixops <deployment> deploy --build-only` from the root of the project. This will generate a new `push-backup` script and show you the path that it built. You can then run the local store script directly.
  * Run `deploy/manage <deployment> ssh-for-each 'cat $(which use-borg-repo)' > use-borg-repo` from the root of the project to see the contents of the file on the server. You can then run this script locally. You may need to make modifications if you're on macOS.

This script simply wraps `borg` and configures it to point to the right repo. Refer to `borg`'s documentation to see the commands.

For example:

  * `./use-borg-repo list` shows all snapshots in the backup
  * `./use-borg-repo extract ::<snapshot-name>` downloads/decrypts/unpacks the snapshot into the current folder.

# MySQL backups

You can also add `module-borg-backup-mysql.nix` to the list of `imports` to get a convenient setup that will optimize, repair, and dump your MySQL databases for backup.

Refer to [this](http://stackoverflow.com/a/25975930/503377) for help on restoring the MySQL database(s) (either the whole thing, or only one database).
To import the MySQL database, you will likely need to add the following two lines to the top of the data file being imported. Try without them first.

```sql
SET foreign_key_checks = 0;  -- Disable these checks while loading.
SET sql_mode = '';           -- Try without this first as it may not be necessary.
```
