{config, ...}: let
  is-dev = config.dartkitos.environment == "dev";
in {
  nix = {
    settings = {
      experimental-features = ["nix-command" "flakes"];
      auto-optimise-store = true;
      trusted-users = ["root" "@wheel"];

      # Disable local building to ensure we only use pre-built binaries from our cache
      max-jobs =
        if is-dev
        then 4
        else 0;

      # Prefer downloading over building, even when a derivation could be built locally.
      always-allow-substitutes = true;
      builders-use-substitutes = true;

      # Only accept signed binaries from cache
      require-sigs = true;

      # ── Substituters ──
      # Order matters: try our Attic first, fall back to upstream.
      substituters = [
        "https://cache.dartkit.pl/dartkitos"
        "https://cache.nixos.org/"
      ];

      trusted-substituters = [
        "https://cache.dartkit.pl/dartkitos"
        "https://cache.nixos.org/"
      ];

      trusted-public-keys = [
        "dartkitos:qbEVIC7PCAV2tfg+nUbUT9LqK30r6sdh9vOOcoiag40="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # No implicit inputs from channels
    registry = {};
    nixPath = [];

    # Garbage collection to save space
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--keep-generations 3";
    };
  };
}
