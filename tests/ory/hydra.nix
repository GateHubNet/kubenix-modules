{ config, ... }:

{
    require = [../test.nix ../../modules/ory/hydra.nix];

    kubernetes.modules.hydra = {
        module = "hydra";
        configuration = {
            storage.class = "ssd";
            image = "imagelocation";
        }
    };
}
