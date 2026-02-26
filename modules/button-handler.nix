{
  pkgs,
  ...
}: let
  # Target is always Raspberry Pi 4 (aarch64-linux)
  buttonHandler = pkgs.callPackage ../pkgs/button-handler.nix {};
in {
  # Expose the button-handler binary on PATH
  environment.systemPackages = [buttonHandler];
}
