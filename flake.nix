{
  description = "DartkitOS - NixOS-based OS for the Dartkit hardware platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-raspberrypi = {
      url = "github:nvmd/nixos-raspberrypi";
      inputs.nixpkgs.follows = "nixpkgs-25-11";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake
    {inherit inputs;} {
      imports = [
        (inputs.import-tree ./configurations)
        (inputs.import-tree ./modules)
        (inputs.import-tree ./pkgs)
      ];

      systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    };
}
