# A borg script builder to be used with `mk-borg-script` that results in
# a script that simply runs borg commands against the repo.

# Arguments provided by `mk-borg-script`
{ borgCmd, ... }: ''${borgCmd ''"$1"''} "''${@:2}"''
