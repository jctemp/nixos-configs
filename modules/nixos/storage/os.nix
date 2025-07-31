{
  config,
  lib,
  ...
}:
let
  cfg = config.nc.system.storage.os;

  createBlankSnapshotScript = poolName: dataset: ''
    set -o errexit
    set -o nounset
    set -o pipefail

    zfsRootFsPath="${poolName}/${dataset}"
    zfsSnapshotBlank="$zfsRootFsPath@blank"

    # We only create a new blank snapshot if it does not exist.
    if ! zfs list -t snapshot -H -o name | grep -q -E "^$zfsSnapshotBlank$"; then
      zfs snapshot "$zfsSnapshotBlank"
    fi
  '';
in
{
  options.nc.system.storage.os = {
    disk = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "Primary disk for OS installation";
    };

    partitions = {
      swap = lib.mkOption {
        type = lib.types.str;
        default = "16G";
        description = "Swap partition size";
      };

      boot = lib.mkOption {
        type = lib.types.str;
        default = "2G";
        description = "Boot partition size";
      };
    };

    root = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "rpool";
        description = "Root pool name";
      };

      compression = lib.mkOption {
        type = lib.types.enum [
          "off"
          "lz4"
          "zstd"
          "gzip"
        ];
        default = "zstd";
        description = "ZFS compression algorithm";
      };

      mirror = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Secondary disk for root pool mirror (null = no mirror)";
      };
    };

    impermanence = {
      persistPath = lib.mkOption {
        type = lib.types.str;
        default = "/persist";
        description = "Path for persistent data";
      };

      directories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "/var/lib/systemd/coredump"
          "/var/lib/nixos"
          "/etc/NetworkManager/system-connections"
        ];
        description = "Directories to persist across reboots";
      };

      files = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Files to persist across reboots";
      };
    };
  };

  config = lib.mkIf config.nc.system.storage.enable {
    boot.initrd.postDeviceCommands = lib.mkAfter ''
      zfs rollback -r ${cfg.root.name}/local/root@blank
    '';

    environment.persistence."${cfg.impermanence.persistPath}" = {
      enable = true;
      hideMounts = true;
      inherit (cfg.impermanence) directories;
      inherit (cfg.impermanence) files;
    };

    # Ensure persist directory is available for boot
    # - disko does not yet support
    fileSystems."${cfg.impermanence.persistPath}".neededForBoot = true;

    disko.devices = {
      disk =
        {
          main = {
            device = cfg.disk;
            type = "disk";
            content = {
              type = "gpt";
              partitions = {
                boot = {
                  label = "BOOT";
                  size = "1M";
                  type = "EF02";
                };

                esp = {
                  label = "EFI";
                  size = cfg.partitions.boot;
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                    mountOptions = [ "umask=0077" ];
                  };
                };

                encryptedSwap = {
                  label = "SWAP";
                  size = cfg.partitions.swap;
                  content = {
                    type = "swap";
                    randomEncryption = true;
                    priority = 100;
                  };
                };

                root = {
                  size = "100%";
                  content = {
                    type = "zfs";
                    pool = cfg.root.name;
                  };
                };
              };
            };
          };
        }
        // lib.optionalAttrs (cfg.root.mirror != null) {
          # We create a secondary disk definition for to host the mirror of the
          # main disk root. The partition root just points to the same ZFS
          # pool and by setting the correct value in the ZFS pool, ZFS will
          # automagically handle the mirroring of the root ZFS partition.
          # TODO: Add mirror for boot to improve the resilience
          secondary = {
            device = cfg.root.mirror;
            type = "disk";
            content = {
              type = "gpt";
              partitions.root = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = cfg.root.name;
                };
              };
            };
          };
        };

      zpool."${cfg.root.name}" = {
        type = "zpool";
        mode = if cfg.root.mirror != null then "mirror" else "";
        rootFsOptions = {
          acltype = "posixacl";
          canmount = "off";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          xattr = "sa";
          inherit (cfg.root) compression;
        };
        mountpoint = "/";
        options = {
          ashift = "12"; # assume to run on NVME otherwise not optimal
          autotrim = "on";
        };

        datasets = {
          # ephemeral
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "local/root" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = createBlankSnapshotScript cfg.root.name "local/root";
          };
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };

          # persistent
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };
          "safe/home" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home";
          };
          "safe/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = cfg.impermanence.persistPath;
          };
        };
      };
    };
  };
}
