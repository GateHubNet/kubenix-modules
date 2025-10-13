{ config, lib, k8s, ...}:

with lib;
with k8s;

{
    config.kubernetes.moduleDefinitions.rafiki-frontend.module = {name, config, module, ...}:
    let env = {
        LOG_LEVEL.value = "debug";
        NODE_ENV.value = "production";

        AUTH_ENABLED.value = config.authEnabled;
        GRAPHQL_URL.value = config.graphqlUrl;
        OPEN_PAYMENTS_URL.value = config.openPaymentsUrl;
        PORT.value = config.port;
    };
    in {
        options = {
            replicas = mkOption {
                description = "Number of Rafiki replicas to run";
                type = types.int;
                default = 1;
            };

            authEnabled = mkOption {
                description = "";
                type = types.bool;
                default = false;
            };

            graphqlUrl = mkOption {
                description = "";
                type = types.str;
                default = "http://rafiki-backend.interledger:3001/graphql";
            };

            openPaymentsUrl = mkOption {
                description = "";
                type = types.str;
                default = "https://ilp.${config.gatehub.externalDomain}";
            };

            port = mkOption {
                description = "";
                type = types.int;
                default = 3010;
            };
        };

        config = {
            kubernetes.resources = {
                deployments.rafiki-frontend = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        replicas = config.replicas;
                        selector.matchLabels.app = name;
                        template.metadata.labels.app = name;

                        template.spec = {
                            nodeSelector.instance-kind = config.instance-kind;

                            containers.server = {
                                image = config.image;
                                imagePullPolicy = config.gatehub.imagePullPolicy;

                                inherit env;

                                ports = [
                                    { containerPort = 3010; name = "http" }
                                ];

                                resources = {
                                    requests = {
                                        cpu = "100m";
                                        memory = "200Mi";
                                    };
                                    limits = {
                                        cpu = "500m";
                                        mempry = "1000Mi";
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };
}