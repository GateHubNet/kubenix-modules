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
        QUOTE_INTERACTION.value = config.incomingPaymentInteraction;
        WAIT_SECONDS.value = config.waitSeconds;

        COOKIE_KEY = secretToEnv config.cookieKey;

        IDENTITY_SERVER_SECRET = secretToEnv config.identityServerSecret;
        REDIS_URL = secretToEnv config.redisUrl;
        AUTH_DATABASE_URL = secretToEnv config.databaseUrl;
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

            cookieKey = mkSecretOption {
                description = "The koa KeyGrip key that is used to sign cookies for an interaction session.";
                default.key = "cookieKey";
            };

            identityServerSecret = mkSecretOption {
                description = "A shared secret between the authorization server and the IdP server; the authorization server will use the secret to secure its IdP-related endpoints. When the IdP server sends requests to the authorization server, the IdP server must provide the secret via an x-idp-secret header.";
                default.key = "identityServerSecret";
            };

            redisUrl = mkSecretOption {
                description = "The connection URL for Redis.";
                default.key = "redisUrl";
            };

            databaseUrl = mkSecretOption {
                description = "The connection URL for Database";
                default.key = "databaseUrl";
            };

            incomingPaymentInteraction = mkOption {
                description = "When true, incoming Open Payments grant requests are interactive";
                type = types.str;
                default = "false";
            };

            interactionCookieSameSite = mkOption {
                description = "Cookie setting for interaction";
                type = types.str;
                default = "none";
            };

            waitSeconds = mkOption {
                description = "The wait time, in seconds, included in a grant request response (grant.continue).";
                type = types.str;
                default = "2";
            };

            databaseCleanupWorkers = mkOption {
                description = "The number of workers processing expired or revoked access tokens.";
                type = types.str;
                default = "1";
            };

            redis = {
                password = mkSecretOption {
                    description = "Name of the Redis password";
                    default.key = "password";
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
                    default.key = "username";
                };

                password = mkSecretOption {
                    description = "Name of the PostgreSQL password";
                    default.key = "password";
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
                    description = "The days until expired and/or revoked access tokens are deleted.";
                    type = types.str;
                    default = "30";
                };

                expirySeconds = mkOption {
                    description = "The expiry time, in seconds, for access tokens.";
                    type = types.str;
                    default = "600";
                };
            };

            urls = {
                authServerDomain = mkOption {
                    description = "Internal URL for ";
                    type = types.str;
                    default = "http://rafiki-auth.interledger:3006";
                };

                auth = mkOption {
                    description = "The public endpoint for your Rafiki instance’s public Open Payments routes.";
                    type = types.str;
                    default = "https://rafiki.${config.gatehub.externalDomain}";
                };

                idp = mkOption {
                    description = "The URL of your IdP’s server, used by the authorization server to inform an Open Payments client of where to redirect the end-user to start interactions.";
                    type = types.str;
                    default = "https://wallet.${config.gatehub.externalDomain}/interledger-consent";
                };
            };

            ports = {
                auth = mkOption {
                    description = "The port of your Open Payments authorization server.";
                    type = types.str;
                    default = "3006";
                };

                admin = mkOption {
                    description = "The port of your Rafiki Auth Admin API server.";
                    type = types.str;
                    default = "3003";
                };

                interaction = mkOption {
                    description = "The port number of your Open Payments interaction-related APIs.";
                    type = types.str;
                    default = "3009";
                };

                introspection = mkOption {
                    description = "The port of your Open Payments access token introspection server.";
                    type = types.str;
                    default = "3007";
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
                            nodeSelector.instance-kind = config.gatehub.instance-kind;

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
                                    { containerPort = 3006; name = "auth"; }
                                    { containerPort = 3003; name = "admin"; }
                                    { containerPort = 3007; name = "introspection"; }
                                    { containerPort = 3009; name = "interaction"; }
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
                        ];
                    };
                };
            };
        };
    };
}