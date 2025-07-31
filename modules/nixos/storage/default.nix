{
  config,
  lib,
  ...
}:
{
  imports = [
    ./os.nix
    ./pools.nix
  ];

  options.nc.system.storage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable storage configuration";
    };

    zfs = {
      autoScrub = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable automatic ZFS scrubbing";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "Scrub interval";
        };
      };

      autoSnapshot = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable automatic ZFS snapshots";
        };
      };

      trim = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable ZFS trimming for SSDs";
        };

        interval = lib.mkOption {
          type = lib.types.str;
          default = "weekly";
          description = "Trim interval";
        };
      };
    };
  };

  config = lib.mkIf config.nc.system.storage.enable {
    boot = {
      supportedFilesystems = [ "zfs" ];
      zfs.forceImportRoot = false;
    };

    services.zfs = {
      autoScrub = {
        inherit (config.nc.system.storage.zfs.autoScrub) enable;
        inherit (config.nc.system.storage.zfs.autoScrub) interval;
      };
      autoSnapshot.enable = config.nc.system.storage.zfs.autoSnapshot.enable;
      trim = {
        inherit (config.nc.system.storage.zfs.trim) enable;
        inherit (config.nc.system.storage.zfs.trim) interval;
      };
    };
  };
}
