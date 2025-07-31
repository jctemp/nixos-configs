{
  config,
  lib,
  ...
}:
let
  cfg = config.nc.system.storage.pools;

  getPoolMode =
    topology:
    if topology == "Single" then
      ""
    else if topology == "Stripe" then
      ""
    else if topology == "Mirror" then
      "mirror"
    else if topology == "RAIDZ" then
      "raidz1"
    else if topology == "RAIDZ2" then
      "raidz2"
    else if topology == "RAIDZ3" then
      "raidz3"
    else
      "";

  validateTopology =
    poolName: poolCfg:
    let
      diskCount = builtins.length poolCfg.disks;
      inherit (poolCfg) topology;
    in
    assert
      (diskCount >= 1) || throw "Pool '${poolName}': At least 1 disk required, got ${toString diskCount}";
    assert
      (topology == "Single" -> diskCount == 1)
      || throw "Pool '${poolName}': Single topology requires exactly 1 disk, got ${toString diskCount}";
    assert
      (topology == "Stripe" -> diskCount >= 2)
      || throw "Pool '${poolName}': Stripe topology requires at least 2 disks, got ${toString diskCount}";
    assert
      (topology == "Mirror" -> diskCount >= 2)
      || throw "Pool '${poolName}': Mirror topology requires at least 2 disks, got ${toString diskCount}";
    assert
      (topology == "RAIDZ" -> diskCount >= 3)
      || throw "Pool '${poolName}': RAIDZ topology requires at least 3 disks, got ${toString diskCount}";
    assert
      (topology == "RAIDZ2" -> diskCount >= 4)
      || throw "Pool '${poolName}': RAIDZ2 topology requires at least 4 disks, got ${toString diskCount}";
    assert
      (topology == "RAIDZ3" -> diskCount >= 5)
      || throw "Pool '${poolName}': RAIDZ3 topology requires at least 5 disks, got ${toString diskCount}";
    true;

  createZfsDatasets =
    poolName: datasets:
    lib.mapAttrs' (name: dataset: {
      name = "${poolName}/${name}";
      value =
        {
          type = "zfs_fs";
          options =
            {
              mountpoint = if dataset.mountable then "legacy" else "none";
            }
            // (lib.optionalAttrs (dataset.compression != "inherit") {
              inherit (dataset) compression;
            })
            // (lib.optionalAttrs (dataset.recordsize != null) {
              inherit (dataset) recordsize;
            })
            // (lib.optionalAttrs (dataset.quota != null) {
              inherit (dataset) quota;
            })
            // (lib.optionalAttrs (dataset.reservation != null) {
              inherit (dataset) reservation;
            })
            // (lib.optionalAttrs dataset.encryption.enable {
              encryption = "on";
              keyformat = dataset.encryption.keyFormat;
              inherit (dataset.encryption) keylocation;
            });
        }
        // (lib.optionalAttrs dataset.mountable {
          inherit (dataset) mountpoint;
        });
    }) datasets;

  validateDataset =
    poolName: datasetName: dataset:
    assert
      (dataset.mountable -> dataset.mountpoint != "")
      || throw "Pool '${poolName}', dataset '${datasetName}': mountpoint required when mountable = true";
    assert
      (
        dataset.recordsize == null
        || lib.hasInfix "K" dataset.recordsize
        || lib.hasInfix "M" dataset.recordsize
      )
      || throw "Pool '${poolName}', dataset '${datasetName}': recordsize must be in K or M (e.g., '128K', '1M')";
    assert
      (
        dataset.quota == null
        || lib.hasInfix "G" dataset.quota
        || lib.hasInfix "T" dataset.quota
        || lib.hasInfix "M" dataset.quota
      )
      || throw "Pool '${poolName}', dataset '${datasetName}': quota must include unit (e.g., '100G', '1T')";
    assert
      (
        dataset.reservation == null
        || lib.hasInfix "G" dataset.reservation
        || lib.hasInfix "T" dataset.reservation
        || lib.hasInfix "M" dataset.reservation
      )
      || throw "Pool '${poolName}', dataset '${datasetName}': reservation must include unit (e.g., '100G', '1T')";
    true;

  enabledPools = lib.filterAttrs (
    poolName: poolCfg:
    poolCfg.enable
    && (validateTopology poolName poolCfg)
    && (lib.all (lib.uncurry (validateDataset poolName)) (lib.attrsToList poolCfg.datasets))
  ) cfg;

in
{
  options.nc.system.storage.pools = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable this pool";
          };

          disks = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Disks for this pool";
          };

          topology = lib.mkOption {
            type = lib.types.enum [
              "Single"
              "Stripe"
              "Mirror"
              "RAIDZ"
              "RAIDZ2"
              "RAIDZ3"
            ];
            default = "Single";
            description = "Pool topology (ZFS native only)";
          };

          mountpoint = lib.mkOption {
            type = lib.types.str;
            description = "Pool mount point";
          };

          compression = lib.mkOption {
            type = lib.types.enum [
              "off"
              "lz4"
              "zstd"
              "gzip"
            ];
            default = "zstd";
            description = "Default compression for pool";
          };

          encryption = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable ZFS native encryption";
            };

            keyFormat = lib.mkOption {
              type = lib.types.enum [
                "passphrase"
                "raw"
                "hex"
              ];
              default = "passphrase";
              description = "Encryption key format";
            };

            keylocation = lib.mkOption {
              type = lib.types.str;
              default = "prompt";
              description = "Key location (prompt, file path, or URI)";
            };
          };

          datasets = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  mountable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                    description = "Whether the dataset should be mountable";
                  };

                  mountpoint = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = "Dataset mount point (required if mountable = true)";
                  };

                  # ZFS native dataset properties
                  compression = lib.mkOption {
                    type = lib.types.enum [
                      "inherit"
                      "off"
                      "lz4"
                      "zstd"
                      "gzip"
                    ];
                    default = "inherit";
                    description = "Dataset compression (inherit from pool or override)";
                  };

                  recordsize = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "128K";
                    description = "Dataset record size (e.g., '128K' for databases, '1M' for large files)";
                  };

                  quota = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "100G";
                    description = "Dataset quota - maximum space this dataset can use";
                  };

                  reservation = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "50G";
                    description = "Dataset reservation - guaranteed space for this dataset";
                  };

                  encryption = {
                    enable = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Enable dataset-level encryption (separate from pool encryption)";
                    };

                    keyFormat = lib.mkOption {
                      type = lib.types.enum [
                        "passphrase"
                        "raw"
                        "hex"
                      ];
                      default = "passphrase";
                      description = "Encryption key format for this dataset";
                    };

                    keylocation = lib.mkOption {
                      type = lib.types.str;
                      default = "prompt";
                      description = "Key location for this dataset";
                    };
                  };
                };
              }
            );
            default = { };
            description = "Datasets to create in this pool";
          };

          options = lib.mkOption {
            type = lib.types.attrs;
            default = {
              ashift = "12";
              autotrim = "on";
            };
            description = "ZFS pool options";
          };

          rootFsOptions = lib.mkOption {
            type = lib.types.attrs;
            default = {
              acltype = "posixacl";
              canmount = "off";
              dnodesize = "auto";
              normalization = "formD";
              relatime = "on";
              xattr = "sa";
            };
            description = "ZFS root filesystem options";
          };
        };
      }
    );
    default = { };
    description = "Additional ZFS pools for permanent storage (NAS, databases, etc.)";
  };

  config = lib.mkIf (config.nc.system.storage.enable && enabledPools != { }) {
    disko.devices = {
      zpool = lib.mapAttrs (poolName: poolCfg: {
        type = "zpool";
        mode = getPoolMode poolCfg.topology;
        inherit (poolCfg) mountpoint;

        rootFsOptions =
          poolCfg.rootFsOptions
          // {
            inherit (poolCfg) compression;
          }
          // (lib.optionalAttrs poolCfg.encryption.enable {
            encryption = "on";
            keyformat = poolCfg.encryption.keyFormat;
            inherit (poolCfg.encryption) keylocation;
          });

        inherit (poolCfg) options;
        datasets = createZfsDatasets poolName poolCfg.datasets;
      }) enabledPools;

      disk = lib.mkMerge (
        lib.mapAttrsToList (
          poolName: poolCfg:
          lib.listToAttrs (
            lib.imap0 (idx: disk: {
              name = "${poolName}_disk_${toString idx}";
              value = {
                device = disk;
                type = "disk";
                content = {
                  type = "gpt";
                  partitions.zfs = {
                    size = "100%";
                    content = {
                      type = "zfs";
                      pool = poolName;
                    };
                  };
                };
              };
            }) poolCfg.disks
          )
        ) enabledPools
      );
    };

    systemd.tmpfiles.rules = lib.flatten (
      lib.mapAttrsToList (
        _poolName: poolCfg:
        lib.mapAttrsToList (
          _datasetName: dataset: lib.optional dataset.mountable "d ${dataset.mountpoint} 0755 root root -"
        ) poolCfg.datasets
      ) enabledPools
    );
  };
}
