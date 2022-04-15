{ config, lib, k8s, ...}:

with lib;
with k8s;

{
    config.kubernetes.moduleDefinitions.hydra.module = {name, config, module, ...}:
    let env = {
        URLS_LOGIN.value = config.urls.login;
        URLS_CONSENT.value = config.urls.consent;
        URLS_SELF_PUBLIC.value = config.urls.selfPublic;
        URLS_SELF_ISSUER.value = config.urls.selfIssuer;

        SERVE_PUBLIC_HOST.value = config.urls.publicHost;
        SERVE_PUBLIC_CORS_ENABLED.value = config.servePublicCorsEnabled;

        SERVE_PUBLIC_PORT.value = config.ports.public;
        SERVE_ADMIN_PORT.value = config.ports.admin;

        LOG_LEVEL.value = config.logLevel;

        # TODO(golobitch): tracing
        # TRACING_PROVIDER.value = config.tracing.provider;
        # TRACING_PROVIDERS_JAEGER_SAMPLING_SERVER_URL.value = config.tracing.sampling.server;
        # TRACING_PROVIDERS_JAEGER_SAMPLING_TYPE.value = config.tracing.sampling.type;
        # TRACING_PROVIDERS_JAEGER_SAMPLING_VALUE.value = config.tracing.sampling.value;
        # TRACING_PROVIDERS_JAEGER_LOCAL_AGENT_ADDRESS.value = config.tracing.agent.url;

        DSN = secretToEnv config.dsn;
        SECRETS_SYSTEM = secretToEnv config.secret;
    };
    in {
        options = {
            image = mkOption  {
                description = "Docker image to user";
                type = types.str;
            };

            replicas = mkOption {
                description = "Number of Hydra replicas to run";
                type = types.int;
                default = 1;
            };

            logLevel = mkOption {
                description = "Log level to use";
                type = types.str;
            };

            secret = mkSecretOption {
                default.key = "secret";
                description = "Hydra secret";
            };

            dsn = mkSecretOption {
                default.key = "dsn";
                description = "DSN to use";
            };

            servePublicCorsEnabled = mkOption {
                description = "Boolean describing if cors is enabled";
                type = types.str;
                default = "true";
            };

            urls = {
                login = mkOption {
                    description = "Login URL";
                    type = types.str;
                };

                consent = mkOption {
                    description = "Consent URL";
                    type = types.str;
                };

                selfPublic = mkOption {
                    description = "Self public URL";
                    type = types.str;
                };

                selfIssuer = mkOption {
                    description = "Self ISSUER URL";
                    type = types.str;
                };

                publicHost = mkOption {
                    description = "Serve public host";
                    type = types.str;
                    default = "0.0.0.0";
                };
            };

            ports = {
                public = mkOption {
                    description = "Serve public port to use";
                    type = types.str;
                    default = "4444";
                };

                admin = mkOption {
                    description = "Admin port to use";
                    type = types.str;
                    default = "4445";
                };
            };

            tracing = {
                provider = mkOption {
                    description = "Tracing provider to use";
                    type = types.str;
                    default = "jaeger";
                };

                sampling = {
                    server = mkOption {
                        description = "Tracing sampling server to use";
                        type = types.str;
                    };

                    type = mkOption {
                        description = "Tracing sampling type to use";
                        type = types.str;
                    };

                    value = mkOption {
                        description = "Tracing sampling value to use";
                        type = types.int;
                    };
                };

                agent = {
                    url = {
                        description = "Tracing agent url to use";
                        type = types.str;
                    };
                };
            };
        };

        config = {
            kubernetes.resources = {
                deployments.hydra = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };
                    spec = {
                        replicas = config.replicas;
                        selector.matchLabels.app = name;
                        template.metadata.labels.app = name;

                        template.spec = {
                            initContainers = [
                                {
                                    name = "hydra-migrate";
                                    inherit env;

                                    image = config.image;
                                    imagePullPolicy = config.gatehub.imagePullPolicy;

                                    command = [ "hydra" "migrate" "sql" "-e" "--yes"];
                                }
                            ];

                            containers.hydra = {
                                image = config.image;
                                imagePullPolicy = config.gatehub.imagePullPolicy;

                                inherit env;

                                command = [ "hydra" "serve" "all" ];

                                resources = {
                                    requests = {
                                        cpu = "200m";
                                        memory = "200Mi";
                                    };
                                    limits = {
                                        cpu = "1000m";
                                        memory = "400Mi";
                                    };
                                };

                                ports = [{
                                    name = "http-public";
                                    containerPort = 4444;
                                }
                                {
                                    name = "http-admin";
                                    containerPort = 4445;
                                }];

                                livenessProbe = {
                                    httpGet = {
                                        path = "/health/alive";
                                        port = 4445;
                                    };
                                    initialDelaySeconds = 30;
                                    periodSeconds = 5;
                                };

                                readinessProbe = {
                                    httpGet = {
                                        path = "/health/ready";
                                        port = 4445;
                                    };
                                };
                            };
                        };
                    };
                };

                services.hydra = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        selector.app = name;
                        ports = [
                            {
                                name = "http";
                                port = 80;
                                targetPort = 4444;
                            }
                            {
                                name = "http-admin";
                                port = 4445;
                                targetPort = 4445;
                            }
                        ];
                    };
                };
            };
        };
    };
}
