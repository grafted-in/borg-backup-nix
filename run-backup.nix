{ bash
, writeScript

, prepBackupScript
, pushBackupScript
}: ''
  #!${bash}/bin/bash

  set -e

  backupTag="''${1:?Specify a tag for this backup}"

  '${prepBackupScript}'
  '${pushBackupScript}' "$backupTag"
''
