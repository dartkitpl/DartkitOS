{
  lib,
  config,
  ...
}: {
  imports = [
    ./networking.nix
    ./nix.nix
    ./services.nix
    ./system.nix
  ];

  options.dartkitos = {
    environment = lib.mkOption {
      type = lib.types.enum ["dev" "prod"];
      default = "dev";
      description = "The environment to use for the DartkitOS configuration.";
    };

    dev-ssh-keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of SSH public keys to add to the dartkit user in the dev environment.";
    };
  };

  config.assertions = [
    {
      assertion = config.dartkitos.environment == "dev" || config.dartkitos.dev-ssh-keys == [];
      message = ''
        Dev SSH keys are allowed only in dev environment.

        environment   = ${config.dartkitos.environment}
        dev-ssh-keys  = ${builtins.toString config.dartkitos.dev-ssh-keys}
      '';
    }
  ];
}
