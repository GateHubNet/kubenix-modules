{ config, ... }:

{
  require = [./test.nix ../modules/songbirdd.nix];

  kubernetes.modules.songbirdd = {
    module = "songbirdd";
    configuration = {
      storage.class = "ssd";
      image = "imagelocation";
    };
  };
}
