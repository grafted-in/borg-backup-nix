{ config, pkgs, lib, ... }:
let

  cfg = config.services.borgBackupMysql;

in with lib; {
  options.services.borgBackupMysql = {
    enable = mkOption {
      type    = types.bool;
      default = false;
      example = literalExample true;
      description = ''
        When enabled, a script will be added to services.borg-backup thatoptimizes, repairs,
        and dumps all MySQL databases to a file.
      '';
    };

    dumpPath = mkOption {
      type = types.path;
      example = literalExample "/root/backup-data/mysql-all-databases.sql";
      description = ''
        Path to a file where the MySQL dump will be stored. The parent directory is created if necessary.
      '';
    };

    user = mkOption {
      type    = types.string;
      default = "root";
      example = literalExample "mysql";
      description = ''User to use when running MySQL commands.'';
    };

    package = mkOption {
      type    = types.package;
      default = pkgs.mysql;
      description = ''MySQL package to use when running MySQL commands.'';
    };
  };

  config = mkIf cfg.enable {
    services.borgBackup.prepScripts = [''
      echo 'Preparing MySQL database backup'
      mkdir -p "$(dirname '${cfg.dumpPath}')"

      echo '## Repairing/optimizing'
      '${cfg.package}/bin/mysqlcheck' -u '${cfg.user}' --auto-repair --optimize --all-databases

      echo '## Exporting database to ${cfg.dumpPath}'
      '${cfg.package}/bin/mysqldump' -u '${cfg.user}' --all-databases --skip-lock-tables > '${cfg.dumpPath}'
    ''];
    services.borgBackup.paths = [ cfg.dumpPath ];
  };
}
