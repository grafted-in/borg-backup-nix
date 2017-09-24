# A borg script builder to be used with `mk-borg-script` that results in
# a script that creates a new backup and pushes it while also pruning.
# Arguments provided by `mk-borg-script`
{ pkgs
, lib

, sshRemote
, borgRepo
, borgCmd
, borgCfg  # Configuration from services.borg-backup
, ...
}: ''
  backupTag="''${1:?Specify a tag for this backup}"

  echo "Pushing backup data via borg to $BORG_REPO"

  ${pkgs.openssh}/bin/ssh "${sshRemote}" mkdir -p '${borgCfg.remoteRepo.path}'
  ${borgCmd "init"}

  ${borgCmd "create"} -v --stats \
    --compression '${borgCfg.compression}' \
    "::{hostname}-$backupTag-{now:%Y-%m-%d}" \
    ${lib.concatMapStringsSep " " (x: "'${x}'") borgCfg.paths} ${lib.concatMapStringsSep " " (x: "--exclude '${x}'") borgCfg.excludedGlobs}

  # Use the `prune` subcommand to maintain daily, weekly and monthly
  # archives of THIS machine. The '{hostname}-' prefix is very important to
  # limit prune's operation to this machine's archives and not apply to
  # other machine's archives also.
  ${borgCmd "prune"} -v --list \
    --prefix "{hostname}-$backupTag-" \
    --keep-daily=${toString borgCfg.keep.daily} \
    --keep-weekly=${toString borgCfg.keep.weekly} \
    --keep-monthly=${toString borgCfg.keep.monthly}
''
