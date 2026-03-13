{
  description = "Flutter development environment";
  inputs = {
    # Pinned to nixos-24.11 to match the DartkitOS builder (Flutter 3.24.4 / Dart 3.5.4).
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };
  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
    };
  in {
    devShell.x86_64-linux = pkgs.mkShell {
      buildInputs = with pkgs; [
        flutter
        chromium
        git
        python3
      ];
      CHROME_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
      shellHook = ''
        flutter --version
        echo "Web server: python3 -m http.server -d build/web 8080"
      '';
    };
  };
}
