{ config, lib, k8s, ...}:

with lib;
with k8s;

{
    config.kubernetes.moduleDefinitions.jaeger.module = {name, config, module, ...}:
    let env = {
        LOG_LEVEL.value = "debug";
    };
    in {
        options = {
            replicas = mkOption {
                description = "Number of Jaeger replicas to run";
                type = types.int;
                default = 1;
            };

            maxReplicas = mkOption {
                description = "Max replicas to run";
                type = types.int;
                default = 10;
            };

            elasticsearchUrl = mkOption {
                description = "URL of elasticsearch to store tracing";
                type = types.str;
                default = "http://elasticsearch.system:9200";
            };

            strategy = mkOption {
                description = "Jaeger deployment strategy";
                type = types.str;
                default = "production";
            };
        };

        config = {
            kubernetes.resources = {
                jaeger.jaeger = {
                    metadata = {
                        name = name;
                        labels.app = name;
                    };

                    spec = {
                        replicas = config.replicas;
                        selector.matchLabels.app = name;
                        template.metadata.labels.app = name;

                        containers.jaeger = {
                            imagePullPolicy = config.gatehub.imagePullPolicy;

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
        };
    };
}
