{ config, lib, k8s, ...}:

with lib;
with k8s;

{
    config.kubernetes.moduleDefinitions.rafiki-backend.module = {name, config, module, ...}:
    let env = {
        LOG_LEVEL.value = "debug";
        NODE_ENV.value = "autopeer";
        GATEHUB_ENV.value = config.gatehub.cluster;
        
        INSTANCE_NAME.value = "gatehub-rafiki-${config.gatehub.cluster}";
        KEY_ID.value = "gh";

        REDIS_URL.value = "redis://:${config.redis.password}@${config.redis.host}:${config.redis.port}";
        DATABASE_URL.value = "postgresql://${config.database.user}:${config.database.password}@${config.database.host}:${config.database.port}/${config.database.name}";

        INCOMING_PAYMENT_WORKER_IDLE.value = config.incomingPayment.workerIdle;
        INCOMING_PAYMENT_WORKERS.value = config.incomingPayment.workers;

        WEBHOOK_TIMEOUT.value = config.webhooks.timeout;
        WEBHOOK_URL.value = config.webhooks.url;
        WEBHOOK_WORKER_IDLE.value = config.webhooks.idle;
        WEBHOOK_WORKERS.value = config.webhooks.workers;

        ADMIN_PORT.value = config.ports.admin;
        CONNECTOR_PORT.value = config.ports.connector;
        OPEN_PAYMENTS_PORT.value = config.ports.openPayments;

        OUTGOING_PAYMENT_WORKER_IDLE.value = config.outgoingPayment.idle;
        OUTGOING_PAYMENT_WORKERS.value = config.outgoingPayment.workers;

        AUTH_SERVER_GRANT_URL.value = config.auth.grantUrl;
        AUTH_SERVER_INTROSPECTION_URL.value = config.auth.introspectionUrl;

        EXCHANGE_RATES_LIFETIME.value = config.rates.lifetime;
        EXCHANGE_RATES_URL.value = config.rates.url;

        GRAPHQL_IDEMPOTENCY_KEY_LOCK_MS.value = config.graphql.keyLockMs;

        USE_TIGERBEETLE.value = config.tigerbeetle.enable;

        WALLET_ADDRESS_URL.value = config.walletAddress.url;
        WALLET_ADDRESS_WORKERS.value = config.walletAddress.workers;
        OPEN_PAYMENTS_URL.value = config.walletAddress.openPaymentsUrl;
        WALLET_ADDRESS_WORKER_IDLE.value = config.walletAddress.workerIdle;

        ILP_ADDRESS.value = config.ilp.address; #TODO: add to services "g.gatehub" and test.gatehub;
        ILP_CONNECTOR_URL.value = config.ilp.connectorUrl;

        QUOTE_LIFESPAN.value = config.quote.lifespan;
        
        SIGNATURE_VERSION.value = config.signature.version;
        SLIPPAGE.value = config.slippage;

        SIGNATURE_SECRET = secretToEnv {
            name = "secret-service-${name}-main";
            key = "signatureSecret";
        };

        STREAM_SECRET = secretToEnv {
            name = "secret-service-${name}-main";
            key = "streamSecret";
        };
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

            instance-kind = mkOption {
                type = types.str;
                description = "Node selector";
                default = config.gatehub.instance-kind;
            };

            signatureSecret = mkSecretOption {
                description = "The secret to generate request header signatures for webhook event requests.";
                default.key = "signatureSecret";
            };

            streamSecret = mkSecretOption {
                description = "The seed secret to generate shared STREAM secrets.";
                default.key = "streamSecret";
            };

            slippage = mkOption {
                description = "The accepted ILP rate fluctuation.";
                type = types.str;
                default = "0.01";
            };

            signature = {
                version = mkOption {
                    description = "The version number to generate request header signatures for webhook events.";
                    type = types.str;
                    default = "1";
                };
            };

            quote = {
                lifespan = mkOption {
                    description = "The time, in milliseconds, an Open Payments quote is valid for.";
                    type = types.str;
                    default = "300000";
                };
            };

            ilp = {
                address = mkOption {
                    description = "The ILP address of your Rafiki instance.";
                    type = types.str;
                };

                connectorUrl = mkOption {
                    description = "The ILP connector address where ILP packets are received.";
                    type = types.str;
                    default = "https://api.${config.gatehub.externalDomain}/rafiki/connector";
                };
            };

            walletAddress = {
                openPaymentsUrl = mkOption {
                    description = "The public endpoint of your Open Payments resource server.";
                    type = types.str;
                    default = "https://ilp.${config.gatehub.externalDomain}";
                };

                url = mkOption {
                    description = "Your Rafiki instance’s internal wallet address.";
                    type = types.str;
                    default = "https://ilp.${config.gatehub.externalDomain}/.well-known/pay";
                };

                workers = mkOption {
                    description = "The number of workers processing wallet address requests.";
                    type = types.str;
                    default = "1";
                };

                workerIdle = mkOption {
                    description = "The time, in milliseconds, that WALLET_ADDRESS_WORKERS wait until checking the empty wallet address request queue again.";
                    type = types.str;
                    default = "200";
                };
            };

            tigerbeetle = {
                enable = mkOption {
                    description = "When true, a TigerBeetle database is used for accounting. When false, a Postgres database is used.";
                    type = types.bool;
                    default = false;
                };
            };

            graphql = {
                keyLockMs = mkOption {
                    description = "The TTL, in milliseconds, for idempotencyKey concurrency lock on GraphQL mutations on the Backend Admin API.";
                    type = types.str;
                    default = "2000";
                };
            };

            rates = {
                url = mkOption {
                    description = "The endpoint your Rafiki instance uses to request exchange rates.";
                    type = types.str;
                    default = "http://rafiki-service.gatehub/v1/rates";
                };

                lifetime = mkOption {
                    description = "The time, in milliseconds, the exchange rates you provide via the EXCHANGE_RATES_URL are valid.";
                    type = types.str;
                    default = "15000";
                };
            };

            auth = {
                grantUrl = mkOption {
                    description = "The endpoint on your Open Payments authorization server to grant a request.";
                    type = types.str;
                    default = "https://rafiki.${config.gatehub.externalDomain}";
                };

                introspectionUrl = mkOption {
                    description = "The endpoint on your Open Payments authorization server to introspect an access token.";
                    type = types.str;
                    default = "http://rafiki-auth.interledger:3007";
                };
            };

            ports = {
                admin = mkOption {
                    description = "The port of your Backend Admin API server.";
                    type = types.str;
                    default = "3001";
                };

                connector = mkOption {
                    description = "The port of the ILP connector for sending packets via ILP over HTTP.";
                    type = types.str;
                    default = "3002";
                };

                openPayments = mkOption {
                    description = "The port of your Open Payments resource server.";
                    type = types.str;
                    default = "3002";
                };
            };

            webhooks = {
                timeout = mkOption {
                    description = "The time, in milliseconds, that your Rafiki instance will wait for a 200 response from your webhook endpoint. If a 200 response is not received, Rafiki will time out and try to send the webhook event again.";
                    type = types.str;
                    default = "200";
                };

                url = mkOption {
                    description = "Your endpoint that consumes webhook events.";
                    type = types.str;
                    default = "http://rafiki-service.gatehub/v1/webhooks";
                };

                idle = mkOption {
                    description = "The time, in milliseconds, that WEBHOOK_WORKERS will wait until they check the empty webhook event queue again.";
                    type = types.str;
                    default = "200";
                };

                workers = mkOption {
                    description = "The number of workers processing webhook events.";
                    type = types.str;
                    default = "1";
                };
            };

            outgoingPayment = {
                idle = mkOption {
                    description = "The time, in milliseconds, that OUTGOING_PAYMENT_WORKERS wait until they check an empty outgoing payment request queue again.";
                    type = types.str;
                    default = "200";
                };

                workers = mkOption {
                    description = "The number of workers processing outgoing payment requests.";
                    type = types.str;
                    default = "4";
                };
            };

            incomingPayment = {
                workerIdle = mkOption {
                    description = "The time, in milliseconds, that INCOMING_PAYMENT_WORKERS will wait until checking an empty incoming payment request queue again.";
                    type = types.str;
                    default = "200";
                };

                workers = mkOption {
                    description = "The number of workers processing incoming payment requests.";
                    type = types.str;
                    default = "1";
                };
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
                    default = "rafiki_backend";
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
        };

        config = {
            kubernetes.resources = {
                deployments.rafiki-backend = {
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
                                    { containerPort = 3001; name = "admin"; }
                                    { containerPort = 3002; name = "connector"; }
                                    { containerPort = 8080; name = "open-payments"; }
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

                services.rafiki-backend = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        selector.app = name;

                        ports = [
                            { name = "admin"; port = 3001; targetPort = 3001; }
                            { name = "connector"; port = 3002; targetPort = 3002; }
                            { name = "open-payments"; port = 80; targetPort = 8080; }
                        ];
                    };
                };
            };
        };
    };
}