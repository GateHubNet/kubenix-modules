[
  ./globals.nix
  ./bitcoin-core.nix
  ./bitcoin-cash-node.nix
  ./dash-core.nix
  ./litecoin-core.nix
  ./rabbitmq.nix
  ./elasticsearch.nix
  ./elasticsearch-curator.nix
  ./redis.nix
  ./nginx.nix
  ./deployer.nix
  ./etcd-operator.nix
  ./etcd.nix
  ./rippled.nix
  ./songbirdd.nix
  ./zetcd.nix
  ./kibana.nix
  ./parity.nix
  ./core-geth.nix
  ./openethereum.nix
  ./beehive.nix
  ./minio.nix
  ./grafana.nix
  ./galera.nix
  ./kube-lego.nix
  ./pachyderm.nix
  ./vault.nix
  ./vault-ui.nix
  ./vault-controller.nix
  ./vault-login.nix
  ./logstash.nix
  ./mariadb.nix
  ./influxdb.nix
  ./kubelog.nix
  ./secret-restart-controller.nix
  ./k8s-request-cert.nix
  ./selfsigned-cert-deployer.nix
  ./nginx-ingress.nix
  ./external-dns.nix
  ./mongo.nix
  ./pritunl.nix
  ./cloud-sql-proxy.nix
  ./mediawiki.nix
  ./k8s-snapshot.nix
  ./goldfish.nix
  ./zookeeper.nix
  ./kafka.nix
  ./ksql.nix
  ./argo-ingress-controller.nix
  ./ambassador.nix
  ./ilp-connector.nix
  ./metabase.nix
  ./locust.nix
  ./ghost.nix
  ./projectsend.nix
] ++ import ./prometheus/module-list.nix
