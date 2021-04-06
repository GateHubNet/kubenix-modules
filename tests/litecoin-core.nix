{ config, ... }:

{
  require = [../modules/litecoin-core.nix];

  kubernetes.modules.my-litecoin = {
    module = "litecoin-core";
    configuration = {
      image = "imagelocation";
      rpcAuth = "test:a7d424b74122e17362e404ec5c5e6d$822c00a871d66c16b7a8ebcc7189624a74e4c2d46e31993012d1d36ade576363";
    };
  };
}
