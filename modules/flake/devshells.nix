{
  perSystem = {pkgs, ...}: {
    devShells.ci = pkgs.mkShell {
      packages = with pkgs; [
        attic-client
      ];
    };

    devShells.button-handler = pkgs.mkShell {
      buildInputs = with pkgs; [
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
