#!/usr/bin/env bash
#
# File: scripts/setup-runner.sh
# Description: One-shot bootstrap for a self-hosted GitHub Actions runner
#              that will run BananaWRT firmware builds via `container:`.
#
#              Installs Docker (if missing), adds the runner user to the
#              docker group, pre-pulls the BananaWRT builder image, and
#              restarts the runner service so group membership takes effect.
#              Idempotent — safe to re-run on existing hosts.
#
# Usage:
#   # Run as root (or with sudo)
#   sudo bash scripts/setup-runner.sh [options]
#
#   # Remote one-liner (curl)
#   curl -fsSL https://raw.githubusercontent.com/SuperKali/BananaWRT/main/scripts/setup-runner.sh \
#     | sudo bash
#
# Options:
#   --runner-user <name>       Runner account (default: runner)
#   --runner-service <name>    systemd unit to restart (default: autodetect)
#   --image <ref>              Image to pre-pull (default: ghcr.io/superkali/bananawrt-builder:latest)
#   --ghcr-user <user>         GHCR username for docker login (optional)
#   --ghcr-token <token>       GHCR token for docker login (optional, reads $GHCR_TOKEN)
#   --no-pull                  Skip image pre-pull
#   --no-restart               Skip runner service restart (you'll do it manually)
#   --dry-run                  Print actions without executing
#   --help                     Show this help
#
# Copyright (c) 2024-2026 SuperKali <hello@superkali.me>
# This is free software, licensed under the MIT License.
#

set -Eeuo pipefail

RUNNER_USER='runner'
RUNNER_SERVICE=''
IMAGE_REF='ghcr.io/superkali/bananawrt-builder:latest'
GHCR_USER=''
GHCR_TOKEN="${GHCR_TOKEN:-}"
DO_PULL=1
DO_RESTART=1
DRY_RUN=0

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_OK='\033[1;32m' C_WARN='\033[1;33m' C_ERR='\033[1;31m' C_INFO='\033[1;36m' C_DIM='\033[2m' C_R='\033[0m'
else
    C_OK='' C_WARN='' C_ERR='' C_INFO='' C_DIM='' C_R=''
fi

log()   { printf '%b[INFO]%b  %s\n'   "$C_INFO" "$C_R" "$*"; }
ok()    { printf '%b[OK]%b    %s\n'   "$C_OK"   "$C_R" "$*"; }
warn()  { printf '%b[WARN]%b  %s\n'   "$C_WARN" "$C_R" "$*"; }
fail()  { printf '%b[ERROR]%b %s\n'   "$C_ERR"  "$C_R" "$*" 1>&2; exit 1; }
run()   { printf '%b+ %s%b\n' "$C_DIM" "$*" "$C_R"; [[ "$DRY_RUN" -eq 1 ]] || eval "$@"; }

# ── CLI parser ────────────────────────────────────────────────────────────────
while (( $# > 0 )); do
    case "$1" in
        --runner-user)    RUNNER_USER="$2";    shift 2 ;;
        --runner-service) RUNNER_SERVICE="$2"; shift 2 ;;
        --image)          IMAGE_REF="$2";      shift 2 ;;
        --ghcr-user)      GHCR_USER="$2";      shift 2 ;;
        --ghcr-token)     GHCR_TOKEN="$2";     shift 2 ;;
        --no-pull)        DO_PULL=0;           shift ;;
        --no-restart)     DO_RESTART=0;        shift ;;
        --dry-run)        DRY_RUN=1;           shift ;;
        --help|-h)
            sed -n '/^# Usage:/,/^# Copyright/p' "$0" | sed 's/^#\s\{0,1\}//'
            exit 0
            ;;
        *) fail "Unknown option: $1 (try --help)" ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
if (( DRY_RUN == 0 )) && [[ "$EUID" -ne 0 ]]; then
    fail "Run as root (use sudo)"
fi

if ! id "$RUNNER_USER" >/dev/null 2>&1; then
    fail "Runner user '$RUNNER_USER' does not exist on this host"
fi

# ── 1. Install Docker ─────────────────────────────────────────────────────────
log "Checking Docker installation"
if command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1; then
    ok "Docker already installed: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'unknown')"
else
    log "Installing Docker CE via get.docker.com"
    run "curl -fsSL https://get.docker.com | sh"
    ok "Docker installed"
fi

# ── 2. Enable & start daemon ──────────────────────────────────────────────────
log "Ensuring Docker daemon is enabled and running"
run "systemctl enable --now docker"
ok "Docker daemon active"

# ── 3. Add runner user to docker group ───────────────────────────────────────
if id -nG "$RUNNER_USER" | tr ' ' '\n' | grep -qx docker; then
    ok "User '$RUNNER_USER' already in 'docker' group"
else
    log "Adding '$RUNNER_USER' to 'docker' group"
    run "usermod -aG docker '$RUNNER_USER'"
    warn "New group membership only applies after process restart"
fi

# ── 4. Autodetect runner service if not given ────────────────────────────────
if [[ -z "$RUNNER_SERVICE" ]]; then
    log "Autodetecting GitHub Actions runner service"
    RUNNER_SERVICE="$(systemctl list-units --type=service --no-legend --plain 'actions.runner.*.service' \
                        2>/dev/null | awk '{print $1}' | head -n1)"
    if [[ -z "$RUNNER_SERVICE" ]]; then
        warn "Could not locate actions.runner.*.service — set --runner-service manually"
    else
        log "Detected runner service: $RUNNER_SERVICE"
    fi
fi

# ── 5. Optional GHCR login (for private images) ──────────────────────────────
if [[ -n "$GHCR_USER" && -n "$GHCR_TOKEN" ]]; then
    log "Logging in to ghcr.io as $GHCR_USER (for runner user $RUNNER_USER)"
    run "sudo -u '$RUNNER_USER' -H bash -c 'echo \"$GHCR_TOKEN\" | docker login ghcr.io -u \"$GHCR_USER\" --password-stdin'"
    ok "ghcr.io authentication cached under $RUNNER_USER's config"
else
    log "Skipping GHCR login (no --ghcr-user/--ghcr-token)"
fi

# ── 6. Pre-pull builder image ────────────────────────────────────────────────
if (( DO_PULL == 1 )); then
    log "Pre-pulling $IMAGE_REF (this may take a minute on first run)"
    if (( DRY_RUN == 0 )); then
        if sudo -u "$RUNNER_USER" -H docker pull "$IMAGE_REF" >/dev/null 2>&1; then
            ok "Image cached locally"
        else
            warn "Pre-pull failed (public image? network? credentials?). The workflow will still try to pull on demand."
        fi
    else
        printf '%b+ sudo -u %s docker pull %s%b\n' "$C_DIM" "$RUNNER_USER" "$IMAGE_REF" "$C_R"
    fi
else
    log "--no-pull given → skipping image pre-pull"
fi

# ── 7. UMask=0000 drop-in so `_temp/*` is world-writable ─────────────────────
# GitHub Actions `container:` bind-mounts the runner's _work/_temp into the
# container. actions/checkout writes save_state files there. If the container
# user (e.g. `builder` UID 1000) doesn't match the runner host UID (e.g.
# github-worker-02 UID 1002), it can't write those files → EACCES.
# UMask=0000 forces the runner to create those files mode 666/777 so any
# container UID can write. Doesn't change file _ownership_, just the mode.
if [[ -n "$RUNNER_SERVICE" ]]; then
    log "Installing UMask=0000 drop-in for $RUNNER_SERVICE"
    drop_dir="/etc/systemd/system/${RUNNER_SERVICE}.d"
    drop_file="$drop_dir/10-umask.conf"
    run "mkdir -p '$drop_dir'"
    if (( DRY_RUN == 0 )); then
        printf '[Service]\nUMask=0000\n' > "$drop_file"
    else
        printf '%b+ tee %s <<<"[Service]\\nUMask=0000"%b\n' "$C_DIM" "$drop_file" "$C_R"
    fi
    run "systemctl daemon-reload"
    ok "UMask drop-in installed"

    # Any _work/ already created by a past run still has mode 700/755; the
    # drop-in only affects files created from now on. Loosen existing tree too.
    work_dir="$(systemctl show -p WorkingDirectory --value "$RUNNER_SERVICE" 2>/dev/null)/_work"
    if [[ -d "$work_dir" ]]; then
        log "Loosening existing $work_dir (chmod -R a+rwX)"
        run "chmod -R a+rwX '$work_dir'"
    fi
fi

# ── 8. Restart runner service so new group + umask take effect ───────────────
if (( DO_RESTART == 1 )) && [[ -n "$RUNNER_SERVICE" ]]; then
    log "Restarting $RUNNER_SERVICE so the new group membership and umask take effect"
    run "systemctl restart '$RUNNER_SERVICE'"
    ok "Runner service restarted"
elif (( DO_RESTART == 0 )); then
    warn "Skipping runner service restart — remember to restart manually:"
    printf '    sudo systemctl restart %s\n' "${RUNNER_SERVICE:-actions.runner.<org>-<repo>.<name>.service}"
fi

# ── 8. Verify ────────────────────────────────────────────────────────────────
log "Final verification"
if (( DRY_RUN == 0 )) && sudo -u "$RUNNER_USER" -H docker ps >/dev/null 2>&1; then
    ok "✓ $RUNNER_USER can talk to Docker"
elif (( DRY_RUN == 0 )); then
    warn "$RUNNER_USER still cannot reach Docker. Try: newgrp docker, or reboot."
fi

printf '\n'
ok "Setup complete. The runner is ready to accept BananaWRT jobs."
