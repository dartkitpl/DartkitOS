{
  perSystem = {pkgs, ...}: let
    pkgs25 = pkgs.nixpkgs25;
  in {
    devShells.ci = pkgs.mkShell {
      packages = with pkgs; [
        attic-client
      ];
    };

    devShells.button-handler = pkgs25.mkShell {
      buildInputs = with pkgs25; [
        cargo
        rustc
        rustfmt
        rust-analyzer
      ];

      shellHook = ''
        echo "Welcome to the button-handler Rust devshell!"
        echo -n "Rust compiler version: "
        rustc --version
      '';
    };
  };
}
