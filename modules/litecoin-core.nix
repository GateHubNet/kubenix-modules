{ config, lib, k8s, ... }:

with k8s;
with lib;

let
  b2s = value: if value then "1" else "0";
in {
  config.kubernetes.moduleDefinitions.litecoin-core.module = {config, module, ...}: let
    litecoindConfig = ''
      ##
      ## litecoind.conf configuration file. Lines beginning with # are comments.
      ##

      # [core]
      # Network-related settings:

      # Run on the test network instead of the real litecoin network
      testnet=${b2s config.testnet}

      # Run a regression test network
      regtest=${b2s config.regtest}

      #
      # JSON-RPC options (for controlling a running Litecoin/litecoind process)
      #

      # server=1 tells Litecoin-Qt and litecoind to accept JSON-RPC commands
      server=${b2s config.server}

      # Log to console
      printtoconsole=1

      # Index all the transactions
      txindex=1

      # Enable replace By Fee
      walletrbf=1

      # Authentication
      rpcauth=${toString config.rpcAuth}

      [main]
      rpcport=9332
      port=9333
      rpcallowip=0.0.0.0/0
      rpcbind=0.0.0.0

      [test]
      rpcport=19332
      port=19333
      rpcallowip=0.0.0.0/0
      rpcbind=0.0.0.0

      [regtest]
      rpcport=19444
      port=19445
      rpcallowip=0.0.0.0/0
      rpcbind=0.0.0.0
    '';
  in {
    options = {
      image = mkOption {
        description = "Name of the litecoind image to use";
        type = types.str;
      };

      replicas = mkOption {
        description = "Number of litecoind replicas";
        type = types.int;
        default = 1;
      };

      server = mkOption {
        description = "Whether to enable RPC server";
        default = true;
        type = types.bool;
      };

      testnet = mkOption {
        description = "Whether to run in testnet mode";
        default = true;
        type = types.bool;
      };

      regtest = mkOption {
        description = "Whether to run in regtest mode";
        default = false;
        type = types.bool;
      };

      rpcAuth = mkOption {
        description = "Rpc auth. The field comes in the format: <USERNAME>:<SALT>$<HASH>";
        type = types.str;
      };

      storage = {
        class = mkOption {
          description = "Name of the storage class to use";
          type = types.nullOr types.str;
          default = null;
        };

        size = mkOption {
          description = "Storage size";
          type = types.str;
          default = if config.testnet || config.regtest then "100Gi" else "250Gi";
        };
      };
    };

    config = {
      kubernetes.resources.statefulSets.litecoind = {
        metadata.name = module.name;
        metadata.labels.app = module.name;
        spec = {
          replicas = config.replicas;
          serviceName = module.name;
          podManagementPolicy = "Parallel";
          selector.matchLabels.app = module.name;
          template = {
            metadata.labels.app = module.name;
            spec = {
              initContainers = [{
                name = "copy-litecoind-config";
                image = "busybox";
                command = ["sh" "-c" "cp /config/litecoin.conf /home/litecoin/.litecoin/litecoin.conf"];
                volumeMounts = [{
                  name = "config";
                  mountPath = "/config";
                } {
                  name = "data";
                  mountPath = "/home/litecoin/.litecoin/";
                }];
              }];
              containers.litecoind = {
                image = config.image;

                volumeMounts = [{
                  name = "data";
                  mountPath = "/home/litecoin/.litecoin/";
                }];

                resources.requests = {
                  cpu = "1000m";
                  memory = "2048Mi";
                };
                resources.limits = {
                  cpu = "1000m";
                  memory = "2048Mi";
                };

                ports = [{
                  name = "rpc-mainnet";
                  containerPort = 9332;
                } {
                  name = "rpc-testnet";
                  containerPort = 19332;
                } {
                  name = "rpc-regtest";
                  containerPort = 19444;
                } {
                  name = "p2p-mainnet";
                  containerPort = 9333;
                } {
                  name = "p2p-testnet";
                  containerPort = 19333;
                }];
              };
              volumes.config.configMap.name = "${module.name}-config";
            };
          };
          volumeClaimTemplates = [{
            metadata.name = "data";
            spec = {
              accessModes = ["ReadWriteOnce"];
              storageClassName = mkIf (config.storage.class != null) config.storage.class;
              resources.requests.storage = config.storage.size;
            };
          }];
        };
      };

      kubernetes.resources.configMaps.litecoind = {
        metadata.name = "${module.name}-config";
        data."litecoin.conf" = litecoindConfig;
      };

      kubernetes.resources.services.litecoind = {
        metadata.name = module.name;
        metadata.labels.app = module.name;
        spec = {
          selector.app = module.name;
          ports = [{
            name = "rpc-mainnet";
            port = 9332;
          } {
            name = "rpc-testnet";
            port = 19332;
          } {
            name = "rpc-regtest";
            port = 19444;
          } {
            name = "p2p-mainnet";
            port = 9333;
          } {
            name = "p2p-testnet";
            port = 19333;
          }];
        };
      };

      kubernetes.resources.podDisruptionBudgets.litecoind = {
        metadata.name = module.name;
        metadata.labels.app = module.name;
        spec.maxUnavailable = 1;
        spec.selector.matchLabels.app = module.name;
      };
    };
  };
}
