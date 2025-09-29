#!/usr/bin/env bash
set -euo pipefail

# ===== Colors / log helpers =====
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ echo -e "${BLUE}[INFO]${NC} $*"; }
ok(){   echo -e "${GREEN}[OK]${NC}   $*"; }
warn(){ echo -e "${YELLOW}[WARN]${NC} $*"; }
err(){  echo -e "${RED}[ERR]${NC}  $*"; }

# ===== Docker helpers =====
check_docker() {
  command -v docker >/dev/null || { err "Docker is not installed"; exit 1; }
}
compose() {
  if docker compose version >/dev/null 2>&1; then docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then docker-compose "$@"
  else err "Docker Compose is not installed (need 'docker compose' or 'docker-compose')"; exit 1; fi
}

# ===== .env handling (no bare 'export') =====
ensure_env() {
  # Create .env if missing
  if [ ! -f .env ]; then
    info "Creating .env with COMPOSE_UID/COMPOSE_GID and defaults"
    cat > .env <<EOF
COMPOSE_UID=$(id -u)
COMPOSE_GID=$(id -g)
COMFYUI_REPO=https://github.com/comfyanonymous/ComfyUI.git
COMFYUI_BRANCH=master
EOF
    ok "Wrote .env"
  fi

  # Ensure required keys exist (append if missing)
  grep -q '^COMPOSE_UID='   .env || echo "COMPOSE_UID=$(id -u)" >> .env
  grep -q '^COMPOSE_GID='   .env || echo "COMPOSE_GID=$(id -g)" >> .env
  grep -q '^COMFYUI_REPO='   .env || echo "COMFYUI_REPO=https://github.com/comfyanonymous/ComfyUI.git" >> .env
  grep -q '^COMFYUI_BRANCH=' .env || echo "COMFYUI_BRANCH=master" >> .env
  grep -q '^TORCH_CHANNEL='  .env || echo "TORCH_CHANNEL=https://download.pytorch.org/whl/nightly/cu129" >> .env
  grep -q '^TORCH_VERSION='  .env || echo "TORCH_VERSION=" >> .env
  grep -q '^TORCHVISION_VERSION=' .env || echo "TORCHVISION_VERSION=" >> .env
  grep -q '^TORCHAUDIO_VERSION='  .env || echo "TORCHAUDIO_VERSION=" >> .env
  grep -q '^FLASH_ATTN_VERSION='  .env || echo "FLASH_ATTN_VERSION=2.8.1" >> .env
  grep -q '^XFORMERS_VERSION='    .env || echo "XFORMERS_VERSION=" >> .env
  grep -q '^XFORMERS_REPO='       .env || echo "XFORMERS_REPO=https://github.com/facebookresearch/xformers.git" >> .env
  grep -q '^XFORMERS_REF='        .env || echo "XFORMERS_REF=main" >> .env
  grep -q '^PYTORCH_CUDA_ALLOC_CONF=' .env || echo "PYTORCH_CUDA_ALLOC_CONF=" >> .env
  grep -q '^COMFYUI_ARGS=' .env || echo "COMFYUI_ARGS=" >> .env

  # Read values safely (no bare export)
  COMPOSE_UID="$(awk -F= '/^COMPOSE_UID=/{print $2; exit}' .env)"
  COMPOSE_GID="$(awk -F= '/^COMPOSE_GID=/{print $2; exit}' .env)"
  COMFYUI_REPO="$(awk -F= '/^COMFYUI_REPO=/{print $2; exit}' .env)"
  COMFYUI_BRANCH="$(awk -F= '/^COMFYUI_BRANCH=/{print $2; exit}' .env)"
  TORCH_CHANNEL="$(awk -F= '/^TORCH_CHANNEL=/{print $2; exit}' .env)"
  TORCH_VERSION="$(awk -F= '/^TORCH_VERSION=/{print $2; exit}' .env)"
  TORCHVISION_VERSION="$(awk -F= '/^TORCHVISION_VERSION=/{print $2; exit}' .env)"
  TORCHAUDIO_VERSION="$(awk -F= '/^TORCHAUDIO_VERSION=/{print $2; exit}' .env)"
  FLASH_ATTN_VERSION="$(awk -F= '/^FLASH_ATTN_VERSION=/{print $2; exit}' .env)"
  XFORMERS_VERSION="$(awk -F= '/^XFORMERS_VERSION=/{print $2; exit}' .env)"
  XFORMERS_REPO="$(awk -F= '/^XFORMERS_REPO=/{print $2; exit}' .env)"
  XFORMERS_REF="$(awk -F= '/^XFORMERS_REF=/{print $2; exit}' .env)"
  PYTORCH_CUDA_ALLOC_CONF="$(awk -F= '/^PYTORCH_CUDA_ALLOC_CONF=/{print $2; exit}' .env)"
  COMFYUI_ARGS="$(awk -F= '/^COMFYUI_ARGS=/{print $2; exit}' .env)"

  export \
    COMPOSE_UID COMPOSE_GID \
    COMFYUI_REPO COMFYUI_BRANCH \
    TORCH_CHANNEL TORCH_VERSION TORCHVISION_VERSION TORCHAUDIO_VERSION \
    FLASH_ATTN_VERSION XFORMERS_VERSION XFORMERS_REPO XFORMERS_REF \
    PYTORCH_CUDA_ALLOC_CONF COMFYUI_ARGS
}

# ===== Create unified workspace layout =====
init_dirs() {
  info "Ensuring workspace tree exists…"
  # Only create the top-level workspace and caches here.
  # Let the container entrypoint manage /workspace/comfyui tree after clone.
  mkdir -p \
    workspace \
    workspace/comfyui \
    workspace/.cache/{pip,hf,torch,xdg}
  ok "Workspace root and caches are present"

  fix_ownership
}

# Try to align ownership to COMPOSE_UID:COMPOSE_GID without requiring host sudo.
# Strategy:
#  1) If already owned correctly, skip.
#  2) Try plain chown (works if current user already owns it).
#  3) Try passwordless sudo (-n). If unavailable or fails, fall back to a root container chown.
fix_ownership() {
  info "Aligning ownership for workspace → ${COMPOSE_UID}:${COMPOSE_GID}"
  local target_owner
  target_owner="${COMPOSE_UID}:${COMPOSE_GID}"

  # Determine current ownership (uid:gid numbers)
  local cur_uid cur_gid cur_owner
  cur_uid=$(stat -c %u workspace 2>/dev/null || echo 0)
  cur_gid=$(stat -c %g workspace 2>/dev/null || echo 0)
  cur_owner="${cur_uid}:${cur_gid}"
  local need_fix=0
  if [ "${cur_owner}" != "${target_owner}" ]; then
    need_fix=1
  else
    # Even if the root matches, subpaths might still be wrong (e.g., created by root in-container)
    if find workspace \( -not -uid "${COMPOSE_UID}" -o -not -gid "${COMPOSE_GID}" \) -print -quit 2>/dev/null | grep -q .; then
      need_fix=1
    fi
  fi

  if [ "$need_fix" -eq 0 ]; then
    ok "Workspace ownership already aligned (${target_owner})"
  else
    # Attempt direct chown first (works if we already own it)
    if chown -R "${target_owner}" workspace 2>/dev/null; then
      ok "Ownership set via direct chown"
    # Attempt passwordless sudo
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null && sudo chown -R "${target_owner}" workspace 2>/dev/null; then
      ok "Ownership set via sudo"
    else
      # Fall back to a one-shot root container using the already-built image
      if command -v docker >/dev/null 2>&1 && docker image inspect comfyui-rtx5090:latest >/dev/null 2>&1; then
        info "Using root container to chown bind mount"
        docker run --rm -u 0:0 -v "${PWD}/workspace:/workspace" --entrypoint bash comfyui-rtx5090:latest -lc \
          "chown -R ${target_owner} /workspace" >/dev/null 2>&1 || true
      fi
      # Verify final state
      cur_uid=$(stat -c %u workspace 2>/dev/null || echo 0)
      cur_gid=$(stat -c %g workspace 2>/dev/null || echo 0)
      cur_owner="${cur_uid}:${cur_gid}"
      if [ "${cur_owner}" = "${target_owner}" ] && ! find workspace \( -not -uid "${COMPOSE_UID}" -o -not -gid "${COMPOSE_GID}" \) -print -quit 2>/dev/null | grep -q .; then
        ok "Ownership set via container fallback"
      else
        warn "Could not change ownership automatically (current ${cur_owner})."
        warn "If needed: sudo chown -R ${target_owner} workspace"
      fi
    fi
  fi

  chmod -R u+rwX,g+rwX,o-rwx workspace 2>/dev/null || true
  ok "Permissions adjusted"
}

doctor() {
  info "Checking writability…"
  local fail=0
  # Always check workspace and caches
  for d in workspace workspace/.cache; do
    if touch "$d/.write_test" 2>/dev/null; then rm -f "$d/.write_test"; ok "$d writable"; else err "$d NOT writable"; fail=1; fi
  done
  # Check ComfyUI tree only if it exists (after first successful run)
  for d in \
    workspace/comfyui \
    workspace/comfyui/config \
    workspace/comfyui/logs \
    workspace/comfyui/output \
    workspace/comfyui/models/checkpoints \
    workspace/comfyui/custom_nodes
  do
    [ -d "$d" ] || continue
    if touch "$d/.write_test" 2>/dev/null; then rm -f "$d/.write_test"; ok "$d writable"; else err "$d NOT writable"; fail=1; fi
  done
  exit $fail
}

start()   {
  info "Preparing workspace and env…"
  ensure_env
  init_dirs
  info "Starting stack…"
  compose up -d
  ok "Up"
  info "ComfyUI → http://localhost:8188"
}
stop()    { info "Stopping stack…"; compose down; ok "Down"; }
restart() { info "Restarting…";     compose restart; ok "Restarted"; }
status()  { compose ps; }
logs()    { info "Logs (Ctrl+C to exit)…"; compose logs -f; }
build()   { info "Build (no cache)…";     compose build --no-cache; ok "Built"; }

update()  {
  info "Updating ComfyUI inside container…"
  compose exec comfyui bash -lc 'set -e; cd /workspace/comfyui && git fetch --all --prune && git pull --rebase || true'
  ok "Repo update attempted (see logs)"
}

setup() {
  info "Running build-wheels.sh if present…"
  if [ -x ./build-wheels.sh ]; then ./build-wheels.sh; else warn "build-wheels.sh not found or not executable; skipping"; fi
  ok "Setup complete"
}

usage(){
  cat <<EOF
Usage: $0 {init|doctor|start|stop|restart|status|logs|build|update|setup|help}

  init     Create 'workspace/' tree, write .env (COMPOSE_UID/GID), fix ownership
  doctor   Verify bind-mounts are writable
  setup    Optional prebuild tasks (e.g., wheels)
  start    Bring up services
  stop     Tear down services
  logs     Tail logs
  build    Rebuild images (no cache)
  update   git pull inside comfyui container
EOF
}

main(){
  check_docker
  cmd="${1:-help}"
  case "$cmd" in
    init)    ensure_env; init_dirs ;;
    doctor)  ensure_env; doctor ;;
    setup)   ensure_env; setup ;;
    start)   ensure_env; start ;;
    stop)    ensure_env; stop ;;
    restart) ensure_env; restart ;;
    status)  ensure_env; status ;;
    logs)    ensure_env; logs ;;
    build)   ensure_env; build ;;
    update)  ensure_env; update ;;
    help|*)  usage ;;
  esac
}
main "$@"
