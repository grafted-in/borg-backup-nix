{ config
, pkgs
, lib
, ...
}:
let

  cfg = config.services.borgBackup;

  # Takes a script builder as described in `mk-borg-script` and produces a script string.
  mkBorgScript = scriptBuilder: pkgs.callPackage ./mk-borg-script.nix {
    inherit scriptBuilder;
    borgCfg = cfg;
  };

  prep-backup = pkgs.writeScriptBin "prep-backup" ''
    #!${pkgs.bash}/bin/bash
    set -e
    ${lib.concatStringsSep "\n" cfg.prepScripts}
  '';

  push-backup = pkgs.writeScriptBin "push-backup" (mkBorgScript ./mk-push-backup.nix);

  run-backup = pkgs.writeScriptBin "run-backup" (pkgs.callPackage ./run-backup.nix {
    prepBackupScript = "${prep-backup}/bin/${prep-backup.name}";
    pushBackupScript = "${push-backup}/bin/${push-backup.name}";
  });

  use-borg-repo = pkgs.writeScriptBin "use-borg-repo" (mkBorgScript ./mk-use-borg-repo.nix);

in with lib; {

  options.services.borgBackup = {
    enable = mkOption {
      type    = types.bool;
      default = false;
      example = literalExample true;
      description = ''
        When enabled, a command-line tools will be added and a systemd
        timer will be created for running borg backups.
      '';
    };

    defaultSnapshotTag = mkOption {
      type    = types.string;
      default = "default";
      example = literalExample "daily";
      description = ''
        A tag to use when naming each borg backup snapshot run by the timer service.
        The snapshot name will also include a date and time.
      '';
    };

    user = mkOption {
      type    = types.string;
      example = "backup";
      default = "root";
      description = ''Name of the system user under which to run backup services.'';
    };

    paths = mkOption {
      type    = types.listOf types.path;
      default = [];
      example = literalExample [ "/root" "/var/www" ];
      description = ''Paths on the system that should be included in the backup.'';
    };

    prepScripts = mkOption {
      type    = types.listOf types.string;
      default = [];
      example = literalExample [ "mysqldump -u root --all-databases > /root/mysql-dump.sql" ];
      description = ''
        Scripts to execute before backup begins. You can use this to do
        database dumps or copy files into the configured backup paths.
      '';
    };

    excludedGlobs = mkOption {
      type    = types.listOf types.string;
      default = [];
      example = literalExample [ ".git/**" ];
      description = ''
        A list of glob patterns that match files which should be excluded from backup snapshots.
      '';
    };

    keep = mkOption {
      type = types.submodule {
        options = {
          daily = mkOption {
            type    = types.int;
            default = 7;
            example = literalExample 7;
            description = ''Number of daily backups to keep before pruning them.'';
          };

          weekly = mkOption {
            type    = types.int;
            default = 4;
            example = literalExample 4;
            description = ''Number of weekly backups to keep before pruning them.'';
          };

          monthly = mkOption {
            type    = types.int;
            default = 6;
            example = literalExample 6;
            description = ''Number of monthly backups to keep before pruning them.'';
          };
        };
      };
      default = { daily = 7; weekly = 4; monthly = 6; };
      description = ''
        How many snapshots to keep in each of the daily/weekly/monthly categories.
      '';
    };

    compression = mkOption {
      type    = types.string;
      default = "lzma,5";
      example = "lzma,5";
      description = ''Compression setting for borg-backup to use on snapshots.'';
    };

    remoteRepo = mkOption {
      type = types.submodule {
        options = {
          host = mkOption {
            type = types.string;
            example = literalExample "rsync.net";
            description = ''Host name of remote borg repo.'';
          };

          user = mkOption {
            type = types.string;
            example = literalExample "backup-user";
            description = ''User name for logging in to remote server.'';
          };

          path = mkOption {
            type = types.string;
            example = literalExample "./backup-data";
            description = ''Path on remote server where backup repo should be stored.'';
          };

          borgPath = mkOption {
            type    = types.string;
            default = "borg";
            example = "borg";
            description = ''Path or name of borg backup executable on remote server.'';
          };

          borgPassword = mkOption {
            type = types.string;
            example = literalExample "xyz";
            description = ''Password for encrypting borg repo.'';
          };
        };
      };
    };

    timerSetting = mkOption {
      type    = types.string;
      default = "*-*-* 10:00:00";  # 10am UTC == 2am PST
      example = "*-*-* 10:00:00";
      description = ''systemd timer setting for periodically running backups.'';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ use-borg-repo prep-backup push-backup run-backup ];

    systemd.services.run-backup = {
      description = "Run the backup script";
      serviceConfig = {
        Type      = "oneshot";
        User      = cfg.user;
        ExecStart = "${run-backup}/bin/${run-backup.name} ${cfg.defaultSnapshotTag}";
      };
    };

    systemd.timers.run-backup = {
      timerConfig = {
        OnCalendar = cfg.timerSetting;
        Persistent = true;
        Unit       = "run-backup.service";
      };
      wantedBy = [ "basic.target" ];
    };
  };
}
