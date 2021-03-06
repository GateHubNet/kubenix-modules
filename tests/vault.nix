{ config, k8s, ... }:

{
  require = [./test.nix ../modules/vault.nix];

  kubernetes.modules.vault = {
    module = "vault";
    configuration = {
      dev.enable = true;
    };
  };

  kubernetes.resources.secrets.vault-token.data = {
    token = k8s.toBase64 "e2bf6c5e-88cc-2046-755d-7ba0bdafef35";
  };
}
