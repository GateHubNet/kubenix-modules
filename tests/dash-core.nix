{ config, ... }:

{
  require = [./test.nix ../modules/dash-core.nix];

  kubernetes.modules.my-dash = {
    module = "dash-core";
    configuration = {
      rpcAuth = "";
      image = "imagelocation";
    };
  };
}
