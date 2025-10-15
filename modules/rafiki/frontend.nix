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
            image = mkOption  {
                description = "Docker image to user";
                type = types.str;
            };

            replicas = mkOption {
                description = "Number of Rafiki replicas to run";
                type = types.int;
                default = 1;
            };

            authEnabled = mkOption {
                description = "When true, only authenticated users can be granted access to Rafiki Admin by an administrator";
                type = types.str;
                default = "false";
            };

            graphqlUrl = mkOption {
                description = "URL for Rafiki’s GraphQL Auth Admin API";
                type = types.str;
                default = "http://rafiki-backend.interledger:3001/graphql";
            };

            openPaymentsUrl = mkOption {
                description = "Your Open Payments API endpoint";
                type = types.str;
                default = "https://ilp.${config.gatehub.externalDomain}";
            };

            port = mkOption {
                description = "Port from which to host the Rafiki Remix app";
                type = types.str;
                default = "3010";
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
                            nodeSelector.instance-kind = config.gatehub.instance-kind;

                            containers.server = {
                                image = config.image;
                                imagePullPolicy = config.gatehub.imagePullPolicy;

                                inherit env;

                                ports = [
                                    { containerPort = 3010; name = "http"; }
                                ];

                                resources = {
                                    requests = {
                                        cpu = "100m";
                                        memory = "200Mi";
                                    };
                                    limits = {
                                        cpu = "500m";
                                        memory = "1000Mi";
                                    };
                                };
                            };
                        };
                    };
                };

                services.rafiki-frontend = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        selector.app = name;

                        ports = [
                            { name = "http"; port = 3010; targetPort = 3010; }
                        ];
                    };
                };
            };
        };
    };
}