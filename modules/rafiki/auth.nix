{ config, lib, k8s, ...}:

with lib;
with k8s;

{
    config.kubernetes.moduleDefinitions.rafiki-auth.module = {name, config, module, ...}:
    let env = {
        LOG_LEVEL.value = "debug";
        NODE_ENV.value = "autopeer";
        ACCESS_TOKEN_DELETION_DAYS.value = config.accessToken.deletionDays;
        ACCESS_TOKEN_EXPIRY_SECONDS.value = config.accessToken.expirySeconds;                                                           
        ADMIN_PORT.value = config.ports.admin;
        AUTH_PORT.value = config.ports.auth;
        AUTH_SERVER_DOMAIN.value = config.urls.authServerDomain;
        AUTH_SERVER_URL.value = config.urls.auth; # TODO: add to services "https://rafiki.gatehub.net";
        DATABASE_CLEANUP_WORKERS.value = config.databaseCleanupWorkers;
        IDENTITY_SERVER_DOMAIN.value = config.urls.idp; #TODO: add to services "https://wallet.gatehub.net/interledger-consent";
        IDENTITY_SERVER_URL.value = config.urls.idp; #TODO: add to services "https://wallet.gatehub.net/interledger-consent";
        INCOMING_PAYMENT_INTERACTION.value = config.incomingPaymentInteraction;
        INTERACTION_COOKIE_SAME_SITE.value = config.interactionCookieSameSite;
        INTERACTION_PORT.value = config.ports.interaction;
        INTROSPECTION_PORT.value = config.ports.introspection;
        PORT.value = config.ports.server;
        QUOTE_INTERACTION.value = config.incomingPaymentInteraction;
        WAIT_SECONDS.value = config.waitSeconds;

        COOKIE_KEY = secretToEnv {
            name = "secret-service-${name}-main";
            key = "cookieKey";
        };

        IDENTITY_SERVER_SECRET = secretToEnv {
            name = "secret-service-${name}-main";
            key = "identityServerSecret";
        };

        REDIS_URL.value = "redis://:${config.redis.password}@${config.redis.host}:${config.redis.port}";
        AUTH_DATABASE_URL.value = "postgresql://${config.database.user}:${config.database.password}@${config.database.host}:${config.database.port}/${config.database.name}";
    };
    in {
        options = {
            replicas = mkOption {
                description = "Number of Rafiki replicas to run";
                type = types.int;
                default = 1;
            };

            incomingPaymentInteraction = mkOption {
                description = "";
                type = types.bool;
                default = false;
            };

            interactionCookieSameSite = mkOption {
                description = "";
                type = types.str;
                default = "none";
            };

            waitSeconds = mkOption {
                description = "";
                type = types.int;
                default = 2;
            };

            databaseCleanupWorkers = mkOption {
                description = "";
                type = types.int;
                default = 1;
            };

            redis = {
                password = mkSecretOption {
                    description = "Name of the Redis password";
                    default = {
                        name = "secret-service-${name}-redis-main";
                        key = "password";
                    };
                };

                host = mkOption {
                    description = "Host where Redis is located";
                    type = types.str;
                    default = "redis.system";
                };

                port = mkOption {
                    description = "Redis port";
                    type = types.str;
                    default = "6379";
                };
            };

            database = {
                name = mkOption {
                    description = "";
                    type = types.str;
                    default = "rafiki_auth";
                };

                user = mkSecretOption {
                    description = "Name of the PostgreSQL user";
                    default = {
                        name = "secret-service-${name}-postgresql-main";
                        key = "username";
                    };
                };

                password = mkSecretOption {
                    description = "Name of the PostgreSQL password";
                    default = {
                        name = "secret-service-${name}-postgresql-main";
                        key = "password";
                    };
                };

                host = mkOption {
                    description = "Host where DB is located";
                    type = types.str;
                    default = "postgresql.system";
                };

                port = mkOption {
                    description = "Database port";
                    type = types.str;
                    default = "5432";
                };
            };

            accessToken = {
                deletionDays = mkOption {
                    description = "";
                    type = types.str;
                    default = "30";
                };

                expirySeconds = mkOption {
                    description = "";
                    type = types.str;
                    default = "600";
                };
            };

            urls = {
                authServerDomain = mkOption {
                    description = "";
                    type = types.str;
                    default = "http://rafiki-auth.interledger:3006";
                };

                auth = mkOption {
                    description = "";
                    type = types.str;
                    default = "https://rafiki.${config.gatehub.externalDomain}";
                };

                idp = mkOption {
                    description = "";
                    type = types.str;
                    default = "https://wallet.${config.gatehub.externalDomain}/interledger-consent";
                };
            };

            ports = {
                auth = mkOption {
                    description = "";
                    type = types.int;
                    default = 3006;
                };

                admin = mkOption {
                    description = "";
                    type = types.int;
                    default = 3003;
                };

                interaction = mkOption {
                    description = "";
                    type = types.int;
                    default = 3009;
                };

                introspection = mkOption {
                    description = "";
                    type = types.int;
                    default = 3007;
                };

                server = mkOption {
                    description = "";
                    type = types.int;
                    default = 3006;
                };
            };
        };

        config = {
            kubernetes.resources = {
                deployments.rafiki-auth = {
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

                            initContainers = [
                                {
                                    name = "migrate-database";
                                    inherit env;

                                    image = config.image;
                                    imagePullPolicy = config.gatehub.imagePullPolicy;

                                    command = ["pnpm" "run" "knex" "--" "migrate:latest" "--env" "production"];
                                }
                            ];

                            containers.server = {
                                image = config.image;
                                imagePullPolicy = config.gatehub.imagePullPolicy;

                                inherit env;

                                ports = [
                                    { containerPort = 3006; name = "auth" }
                                    { containerPort = 3003; name = "admin" }
                                    { containerPort = 3007; name = "introspection" }
                                    { containerPort = 3009; name = "interaction" }
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
                        }
                    };
                };

                services.rafiki-auth = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        selector.app = name;

                        ports = [
                            { name = "auth"; port = 3006; targetPort = 3006; }
                            { name = "admin"; port = 3003; targetPort = 3003; }
                            { name = "introspection"; port = 3007; targetPort = 3007; }
                            { name = "interaction"; port = 3009; targetPort = 3009; }
                        ]
                    };
                };
            };

            kubernetes.customResources.secret-claims.main = {
                metadata = {
                    name = "secret-service-${name}-main";
                    labels.app = "secret-service-${name}-main";
                };

                spec = {
                    type = "Opaque";
                    path = "secret/service/${name}/main";
                };
            };

            kubernetes.customResources.secret-claims.postgresql = {
                metadata = {
                    name = "secret-service-${name}-postgresql-main";
                    labels.app = "secret-service-${name}-postgresql-main";
                };

                spec = {
                    type = "Opaque";
                    path = "secret/service/${name}/postgresql/main";
                };
            };

            kubernetes.customResources.secret-claims.redis = {
                metadata = {
                    name = "secret-service-${name}-redis-main";
                    labels.app = "secret-service-${name}-redis-main";
                };

                spec = {
                    type = "Opaque";
                    path = "secret/service/${name}/redis/main";
                };
            };
        };
    };
}