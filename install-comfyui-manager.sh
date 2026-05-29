#!/usr/bin/env bash
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$*"; }
ok(){ printf "%b[OK]%b   %s\n" "$GREEN" "$NC" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$*"; }
err(){ printf "%b[ERR]%b  %s\n" "$RED" "$NC" "$*"; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CUSTOM_NODE_DIR="${SCRIPT_DIR}/workspace/comfyui/custom_nodes"
TARGET_DIR="${CUSTOM_NODE_DIR}/ComfyUI-Manager"
REPO_URL="https://github.com/ltdrdata/ComfyUI-Manager.git"
BRANCH="main"

mkdir -p "$CUSTOM_NODE_DIR"

if [[ -d "$TARGET_DIR/.git" ]]; then
  info "Updating existing ComfyUI-Manager checkout"
  git -C "$TARGET_DIR" fetch --all --prune
  git -C "$TARGET_DIR" checkout "$BRANCH"
  git -C "$TARGET_DIR" pull --ff-only || warn "Fast-forward failed; check repo state manually"
  ok "ComfyUI-Manager updated"
else
  info "Cloning ComfyUI-Manager into custom_nodes"
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
  ok "ComfyUI-Manager installed"
fi

info "Restart ComfyUI (./manage.sh restart) so the manager loads into the UI"
