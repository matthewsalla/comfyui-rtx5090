#!/usr/bin/env bash
set -euo pipefail

: "${HOME:=/workspace}"
: "${COMFYUI_REPO:=https://github.com/comfyanonymous/ComfyUI.git}"
: "${COMFYUI_BRANCH:=master}"
: "${COMFYUI_ARGS:=}"

: "${XDG_CACHE_HOME:=/workspace/.cache/xdg}"
: "${HF_HOME:=/workspace/.cache/hf}"
: "${TORCH_HOME:=/workspace/.cache/torch}"
: "${PIP_CACHE_DIR:=/workspace/.cache/pip}"

export HOME XDG_CACHE_HOME HF_HOME TORCH_HOME PIP_CACHE_DIR

# Ensure we operate from /workspace even if WORKDIR pointed at a removed path
cd /workspace

# Ensure cache dirs only (repo dirs are handled after clone)
mkdir -p /workspace/.cache/{pip,hf,torch,xdg}

# Git config
git config --global --add safe.directory /workspace/comfyui || true
git config --global http.timeout 300 || true
git config --global url."https://github.com/".insteadOf git://github.com/ || true

# Clone or update ComfyUI
if [ ! -d /workspace/comfyui/.git ]; then
  echo "[INFO] Cloning ComfyUI → ${COMFYUI_REPO} (branch: ${COMFYUI_BRANCH})"
  # If the directory exists but isn't a git repo, it must be empty for clone to succeed.
  if [ -d /workspace/comfyui ] && [ -n "$(ls -A /workspace/comfyui 2>/dev/null || true)" ]; then
    echo "[ERROR] /workspace/comfyui exists and is not empty; cannot clone into it."
    echo "       Move or clear that folder, then restart the container."
    exit 1
  fi
  rm -rf /workspace/comfyui || true
  git clone --depth=1 --branch "${COMFYUI_BRANCH}" "${COMFYUI_REPO}" /workspace/comfyui
else
  echo "[INFO] Updating existing ComfyUI repo"
  (cd /workspace/comfyui && git fetch --all --prune && git pull --rebase || true)
fi

# After clone/update, ensure ComfyUI working directories exist
if [ -d /workspace/comfyui ]; then
  mkdir -p \
    /workspace/comfyui/models/{checkpoints,clip,clip_vision,controlnet,embeddings,ipadapter,lora,unet,vae,upscale_models} \
    /workspace/comfyui/{custom_nodes,config,logs,output}
fi

# Record version
if [ -d /workspace/comfyui/.git ]; then
  COMMIT_HASH="$(cd /workspace/comfyui && git rev-parse HEAD || echo unknown)"
  date +"comfyui-nightly-%Y-%m-%d (${COMMIT_HASH})" > /workspace/comfyui/.version || true
fi

# Install deps (best-effort)
if [ -f /workspace/comfyui/requirements.txt ]; then
  echo "[INFO] Installing ComfyUI requirements"
  python3 -m pip install --upgrade pip wheel setuptools >/dev/null 2>&1 || true
  python3 -m pip install -r /workspace/comfyui/requirements.txt || true
fi

# Launch
cd /workspace/comfyui
echo "[INFO] Starting ComfyUI on 0.0.0.0:8188"
# Allow optional extra CLI args supplied via COMFYUI_ARGS env
if [ -n "${COMFYUI_ARGS}" ]; then
  # shellcheck disable=SC2086
  set -- ${COMFYUI_ARGS} "$@"
fi
exec python3 main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --enable-cors-header \
  --cuda-device 0 \
  "$@"
