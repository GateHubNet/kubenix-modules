{ config, lib, k8s, ... }:

with lib;
with k8s;

{
  # kubenix module that implements vault login sidecar that 
  kubernetes.moduleDefinitions.vault-login-sidecar.prefixResources = false;
  kubernetes.moduleDefinitions.vault-login-sidecar.assignAsDefaults = true;
  kubernetes.moduleDefinitions.vault-login-sidecar.module = { name, module, config, ... }: {
    options = {
      resourcePath = mkOption {
        description = "Path to resource where to apply vault-login sidecar";
        type = types.listOf types.str;
      };

      serviceAccountName = mkOption {
        description = "Name of the service account that login role applies to";
        type = types.str;
      };

      mountContainer = mkOption {
        description = "Name of the container where to mount sidecar";
        type = types.nullOr types.str;
        default = null;
      };

      mountPath = mkOption {
        description = "Token mount path";
        type = types.path;
        default = "/vault";
      };

      method = mkOption {
        description = "Login method";
        type = types.enum ["kubernetes"];
        default = "kubernetes";
      };

      kubernetes.token = mkSecretOption {
        description = "Optional secret where to read kubernetes token from";
        default = null;
      }; 

      vault = {
        address = mkOption {
          description = "Vault address";
          default = "http://vault:8200";
          type = types.str;
        };

        caCert = mkOption {
          description = "Name of the secret for vault cert";
          type = types.nullOr types.str;
          default = null;
        };

        role = mkOption {
          description = "Login role to use";
          type = types.str;
        };
      };

      renewToken = mkOption {
        description = "Whether to enable token renew";
        type = types.bool;
        default = true;
      };

      tokenRenewPeriod = mkOption {
        description = "Token renew period";
        type = types.int;
        default = 1800;
      };
    };

    config = mkMerge [{
      kubernetes.resources = (setAttrByPath config.resourcePath {
        initContainers = [{
          name = "${module.name}-vault-login";
          image = "vault:1.9.4";
          imagePullPolicy = "IfNotPresent";
          env = {
            VAULT_CACERT.value =
              if (config.vault.caCert != null)
              then "/etc/certs/vault/ca.crt"
              else "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
            VAULT_ADDR.value = config.vault.address;
            KUBERNETES_TOKEN = mkIf (config.kubernetes.token != null) (secretToEnv config.kubernetes.token);
          };
          command = ["sh" "-ec" ''
            vault write -field=token auth/kubernetes/login \
              role=${config.vault.role} \
              jwt=${
                if (config.kubernetes.token != null)
                then "$KUBERNETES_TOKEN"
                else "$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
              } > /vault/token
            cp $VAULT_CACERT /vault
            echo "vault token retrived"
          ''];
          volumeMounts."/etc/certs/vault" = mkIf (config.vault.caCert != null) {
            name = "${module.name}-vault-cert";
            mountPath = "/etc/certs/vault";
          };
          volumeMounts."/vault" = {
            name = "${module.name}-vault-token";
            mountPath = "/vault";
          };
        }];
        containers = {
          "${config.mountContainer}" = mkIf (config.mountContainer != null) {
            volumeMounts."${module.name}-vault-token" = {
              name = "${module.name}-vault-token";
              mountPath = config.mountPath;
            };
          };

          "${module.name}-token-renewer" = mkIf config.renewToken {
            image = "vault:1.9.4";
            imagePullPolicy = "IfNotPresent";
            command = ["sh" "-ec" ''
              export VAULT_TOKEN=$(cat /vault/token)

              while true; do
                echo "renewing vault token"
                vault token renew >/dev/null
                sleep ${toString config.tokenRenewPeriod}
              done
            ''];
            env = {
              VAULT_CACERT.value =
                if (config.vault.caCert != null)
                then "/etc/certs/vault/ca.crt"
                else "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";
              VAULT_ADDR.value = config.vault.address;
            };
            volumeMounts."/etc/certs/vault" = mkIf (config.vault.caCert != null) {
              name = "${module.name}-vault-cert";
              mountPath = "/etc/certs/vault";
            };
            volumeMounts."/vault" = {
              name = "${module.name}-vault-token";
              mountPath = "/vault";
            };
          };
        };
        volumes."${module.name}-vault-cert" = mkIf (config.vault.caCert != null) {
          secret.secretName = config.vault.caCert;
        };
        volumes."${module.name}-vault-token".emptyDir = {};
      });
    }
    {
      kubernetes.resources.clusterRoleBindings."${module.namespace}-${name}-vault-login" = {
        apiVersion = "rbac.authorization.k8s.io/v1beta1";
        metadata.labels.app = name;
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "system:auth-delegator";
        };
        subjects = [{
          kind = "ServiceAccount";
          name = config.serviceAccountName;
          namespace = module.namespace;
        }];
      };
    }];
  };
}
