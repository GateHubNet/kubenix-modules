{ config, ... }:

{
  require = [./test.nix ../modules/rippled.nix];

  kubernetes.modules.rippled = {
    module = "songbirdd";
    configuration = {
      nodeSize = "tiny";
      storage.class = "ssd";
      autovalidator.enable = true;
    };
  };
}
