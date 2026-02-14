# ============================================================
# dartkitos-update.nix
# ============================================================
# Update script for DartkitOS OTA updates.
#
# Checks the GitHub Releases API for new versions, compares with
# the currently running version, and triggers nixos-rebuild switch
# using the tagged flake reference. All derivations are pre-built
# and served from the Attic binary cache — the consumer never
# compiles anything.
# ============================================================
{
  writeShellApplication,
  coreutils,
  curl,
  jq,
  gnutar,
  gzip,
  nix,
  nixos-rebuild,
  systemd,
  git,
  gnugrep,
  gawk,
  diffutils,
}:
writeShellApplication {
  name = "dartkitos-update";

  runtimeInputs = [
    coreutils
    curl
    jq
    gnutar
    gzip
    nix
    nixos-rebuild
    systemd
    git
    gnugrep
    gawk
    diffutils
  ];

  text = ''
    set -euo pipefail

    # ── Configuration (overridable via environment) ──────────────
    GITHUB_REPO="''${DARTKITOS_GITHUB_REPO:-dartkitpl/DartkitOS}"
    FLAKE_ATTR="''${DARTKITOS_FLAKE_ATTR:-dartkitos}"
    VERSION_FILE="/etc/dartkitos-version"
    STATE_DIR="/var/lib/dartkitos-update"
    LOG_TAG="dartkitos-update"

    # ── Handle --version flag ────────────────────────────────────
    if [[ "''${1:-}" == "--version" || "''${1:-}" == "-v" ]]; then
      if [[ -f "''${VERSION_FILE}" ]]; then
        cat "''${VERSION_FILE}"
      else
        echo "unknown"
      fi
      exit 0
    fi

    # ── Helpers ──────────────────────────────────────────────────
    log()  { echo "[''${LOG_TAG}] $*"; }
    info() { log "INFO:  $*"; }
    warn() { log "WARN:  $*"; }
    err()  { log "ERROR: $*"; }

    die() {
      err "$@"
      exit 1
    }

    # ── Ensure state directory exists ────────────────────────────
    mkdir -p "''${STATE_DIR}"

    # ── Read current version (commit SHA) ────────────────────────
    if [[ -f "''${VERSION_FILE}" ]]; then
      CURRENT_REV="$(tr -d '[:space:]' < "''${VERSION_FILE}")"
    else
      CURRENT_REV="unknown"
    fi
    info "Current revision: ''${CURRENT_REV}"

    # ── Check GitHub for latest release ──────────────────────────
    info "Checking GitHub releases for ''${GITHUB_REPO}..."
    RELEASE_JSON="$(curl -sf --max-time 30 \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/''${GITHUB_REPO}/releases/latest")" \
      || die "Failed to fetch latest release from GitHub"

    LATEST_TAG="$(echo "''${RELEASE_JSON}" | jq -r '.tag_name')"
    RELEASE_NAME="$(echo "''${RELEASE_JSON}" | jq -r '.name // .tag_name')"
    IS_PRERELEASE="$(echo "''${RELEASE_JSON}" | jq -r '.prerelease')"

    if [[ -z "''${LATEST_TAG}" || "''${LATEST_TAG}" == "null" ]]; then
      die "Could not determine latest release tag"
    fi

    info "Latest release: ''${LATEST_TAG} (''${RELEASE_NAME})"

    # Skip pre-releases unless explicitly opted in
    if [[ "''${IS_PRERELEASE}" == "true" && "''${DARTKITOS_ALLOW_PRERELEASE:-0}" != "1" ]]; then
      info "Latest release is a pre-release — skipping. Set DARTKITOS_ALLOW_PRERELEASE=1 to opt in."
      exit 0
    fi

    # ── Resolve the tag to a commit SHA ───────────────────────────
    # The GitHub API for releases doesn't directly give us the commit
    # SHA, but the git ref API does.
    TAG_SHA_JSON="$(curl -sf --max-time 15 \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/''${GITHUB_REPO}/git/ref/tags/''${LATEST_TAG}")" \
      || die "Failed to resolve tag ''${LATEST_TAG} to a commit"

    TAG_OBJ_TYPE="$(echo "''${TAG_SHA_JSON}" | jq -r '.object.type')"
    TAG_OBJ_SHA="$(echo "''${TAG_SHA_JSON}" | jq -r '.object.sha')"

    # If it's an annotated tag, we need to dereference to the commit
    if [[ "''${TAG_OBJ_TYPE}" == "tag" ]]; then
      COMMIT_JSON="$(curl -sf --max-time 15 \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/''${GITHUB_REPO}/git/tags/''${TAG_OBJ_SHA}")" \
        || die "Failed to dereference annotated tag"
      RELEASE_REV="$(echo "''${COMMIT_JSON}" | jq -r '.object.sha')"
    else
      RELEASE_REV="''${TAG_OBJ_SHA}"
    fi

    info "Release commit: ''${RELEASE_REV}"

    # ── Compare revisions ────────────────────────────────────────
    if [[ "''${CURRENT_REV}" == "''${RELEASE_REV}" ]]; then
      info "Already running release ''${LATEST_TAG} (''${CURRENT_REV}). Nothing to do."
      exit 0
    fi

    info "Update available: ''${CURRENT_REV:0:8} -> ''${LATEST_TAG} (''${RELEASE_REV:0:8})"

    # ── Record current kernel for reboot detection ───────────────
    CURRENT_KERNEL="$(readlink /run/current-system/kernel 2>/dev/null || echo "")"

    # ── Perform the rebuild ──────────────────────────────────────
    # Uses the tagged flake ref so the exact commit is pinned.
    FLAKE_REF="github:''${GITHUB_REPO}/''${LATEST_TAG}#''${FLAKE_ATTR}"

    info "Rebuilding from: ''${FLAKE_REF}"
    info "All store paths should come from the binary cache..."

    if nixos-rebuild switch \
        --flake "''${FLAKE_REF}" \
        --option accept-flake-config true \
        --option narinfo-cache-negative-ttl 0 \
        2>&1 | tee "''${STATE_DIR}/last-rebuild.log"; then
      info "Rebuild successful!"
    else
      err "Rebuild FAILED — system remains on ''${CURRENT_REV:0:8}"
      err "Check ''${STATE_DIR}/last-rebuild.log for details"
      exit 1
    fi

    # ── Record successful update ─────────────────────────────────
    echo "''${LATEST_TAG}" > "''${STATE_DIR}/last-successful-update"
    date -Iseconds > "''${STATE_DIR}/last-update-time"

    # ── Reboot if kernel changed ─────────────────────────────────
    NEW_KERNEL="$(readlink /run/current-system/kernel 2>/dev/null || echo "")"

    if [[ "''${CURRENT_KERNEL}" != "''${NEW_KERNEL}" && -n "''${NEW_KERNEL}" ]]; then
      info "Kernel changed — scheduling reboot in 10 seconds..."
      echo "''${LATEST_TAG}" > "''${STATE_DIR}/reboot-pending-version"
      # Give services time to settle, then reboot
      shutdown -r +0 "DartkitOS update: rebooting for kernel change (''${LATEST_TAG})"
    else
      info "No kernel change — switch is already live."
    fi

    info "Update to ''${LATEST_TAG} complete."
  '';
}
