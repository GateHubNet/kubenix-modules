{ config, lib, k8s, ... }:

with k8s;
with lib;

{
  config.kubernetes.moduleDefinitions.flare-node.module = {config, module, ...}: {
    options = {
      image = mkOption {
        description = "Name of the flare-node image to use";
        type = types.str;
      };

      replicas = mkOption {
        description = "Number of flare-node replicas";
        type = types.int;
        default = 1;
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
          default = "200Gi";
        };
      };
    };

    config = {
      kubernetes.resources.statefulSets.flare-node = {
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
              containers.flare-node = {
                image = config.image;
                imagePullPolicy = "IfNotPresent";

                volumeMounts = [{
                  name = "data";
                  mountPath = "/app/db/";
                }];

                resources.requests = {
                  cpu = "1000m";
                  memory = "8Gi";
                };

                resources.limits = {
                  cpu = "500m";
                  memory = "4Gi";
                };

                ports = [{
                  name = "nodeport";
                  containerPort = 9650;
                }];

                livenessProbe = {
                  exec.command = ["sh" "-c" ''
                    if [ $(curl -s http://localhost:9650/ext/health | jq -r '.checks.network.message.connectedPeers') -lt "17" ]; then
                    exit 1;
                    fi
                  ''];
                  initialDelaySeconds = 60;
                  periodSeconds = 60;
                  failureThreshold = 5;
                  successThreshold = 1;
                };
                
                readinessProbe = {
                  exec.command = ["sh" "-c" ''
                    if [ $(curl -s http://localhost:9650/ext/health | jq -r '.healthy') != "true" ]; then
                    exit 1;
                    fi
                  ''];
                  initialDelaySeconds = 60;
                  periodSeconds = 60;
                  failureThreshold = 3;
                  successThreshold = 1;
                };
              };
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

      kubernetes.resources.services.flare-node = {
        metadata.name = module.name;
        metadata.labels.app = module.name;
        spec = {
          selector.app = module.name;
          ports = [{
            name = "nodeport";
            port = 9650;
          }];
        };
      };

      kubernetes.resources.podDisruptionBudgets.flare-node = {
        metadata.name = module.name;
        metadata.labels.app = module.name;
        spec.maxUnavailable = 1;
        spec.selector.matchLabels.app = module.name;
      };
    };
  };
}
