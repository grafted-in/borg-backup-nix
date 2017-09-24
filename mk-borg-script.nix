# Generic interface for working with a specific borg repo.
{ pkgs
, borgbackup

# Borg settings
, borgCfg

  # A derivation that takes some borg-specific params and returns a string to
  # splice into a script that has access to the borg repo:
  # {
  #   sshRemote : string # is the host and path to the SSH remote server for the repo
  #   remotePath : string # path on remote server where repo exists
  #   borgRepo : string # is the full path to the borg repo (include the SSH remote host)
  #   borgCmd : (string -> string) # is a function that yields a command to borg given a
  #                                # subcommand (like 'list' or 'create')
  # }
, scriptBuilder
}: let
  sshRemote = "${borgCfg.remoteRepo.user}@${borgCfg.remoteRepo.host}";
  borgRepo  = "${sshRemote}:${borgCfg.remoteRepo.path}";
  borgCmd = subcommand: "'${borgbackup}/bin/borg' ${subcommand} --remote-path '${borgCfg.remoteRepo.borgPath}'";
in ''
  #!${pkgs.stdenv.shell}

  export BORG_PASSPHRASE='${borgCfg.remoteRepo.borgPassword}'
  export BORG_RSH='${pkgs.openssh}/bin/ssh'
  export BORG_REPO='${borgRepo}'

  ${ pkgs.callPackage scriptBuilder {
    inherit sshRemote borgRepo borgCmd borgCfg;
  } }
''
