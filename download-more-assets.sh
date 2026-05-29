#!/usr/bin/env bash
# Pull additional checkpoints, ControlNet weights, upscalers, and AnimateDiff models.
# Skips anything that already exists.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$*"; }
ok(){ printf "%b[OK]%b   %s\n" "$GREEN" "$NC" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$*"; }
err(){ printf "%b[ERR]%b  %s\n" "$RED" "$NC" "$*"; }

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COMFYUI_DIR="${COMFYUI_DIR:-${ROOT_DIR}/workspace/comfyui}"
MODELS_DIR="${MODELS_DIR:-${COMFYUI_DIR}/models}"
ANIMATEDIFF_DIR="${COMFYUI_DIR}/custom_nodes/AnimateDiff/models"
MOTION_LORA_DIR="${ANIMATEDIFF_DIR}/Motion_LoRAs"

mkdir -p "$MODELS_DIR" "$ANIMATEDIFF_DIR" "$MOTION_LORA_DIR"

HF_TOKEN="${HUGGING_FACE_HUB_TOKEN:-${HF_TOKEN:-}}"
if [[ -z "$HF_TOKEN" && -f "${ROOT_DIR}/.env" ]]; then
  HF_TOKEN=$(awk -F= '/^HF_TOKEN=/{print $2; exit}' "${ROOT_DIR}/.env")
fi
HF_TOKEN="${HF_TOKEN//\"/}"
HEADER=()
if [[ -n "$HF_TOKEN" ]]; then
  HEADER=(-H "Authorization: Bearer ${HF_TOKEN}")
fi

ASSETS=(
  "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors|checkpoints/sd_xl_base_1.0.safetensors|"
  "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors|checkpoints/sd_xl_refiner_1.0.safetensors|"
  "https://huggingface.co/Lykon/DreamShaper/resolve/main/DreamShaper_8_pruned.safetensors|checkpoints/DreamShaper_8_BakedVae.safetensors|"
  "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_scribble.pth|controlnet/control_v11p_sd15_scribble.pth|"
  "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11f1p_sd15_depth.pth|controlnet/control_v11f1p_sd15_depth.pth|"
  "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11e_sd15_shuffle.pth|controlnet/control_v11e_sd15_shuffle.pth|"
)

ANIMATEDIFF_ASSETS=(
  "https://huggingface.co/guoyww/animatediff/resolve/main/mm_sd_v15_v2.ckpt|custom_nodes/AnimateDiff/models/mm_sd_v15_v2.ckpt|"
)

TEMP_DIR="${ROOT_DIR}/.tmp-downloads"
mkdir -p "$TEMP_DIR"

summary=()

download() {
  local url=$1
  local rel_path=$2
  local requirement=$3

  if [[ "$requirement" == "token" && -z "$HF_TOKEN" ]]; then
    warn "Skipping ${rel_path} (requires HF token)"
    summary+=("SKIP token ${rel_path}")
    return
  fi

  local dest="${MODELS_DIR}/${rel_path}"
  local dest_dir
  dest_dir=$(dirname "$dest")
  mkdir -p "$dest_dir"

  if [[ -s "$dest" ]]; then
    warn "Already present → ${rel_path}"
    summary+=("SKIP exists ${rel_path}")
    return
  fi

  local tmp="${TEMP_DIR}/$(basename "$rel_path")"
  info "Downloading ${rel_path}"
  if curl --fail -L --retry 3 --retry-delay 5 --progress-bar "${HEADER[@]}" -o "$tmp" "$url"; then
    mv "$tmp" "$dest"
    ok "Saved ${rel_path}"
    summary+=("OK ${rel_path}")
  else
    err "Failed ${rel_path}"
    summary+=("ERR ${rel_path}")
    rm -f "$tmp"
  fi
}

for entry in "${ASSETS[@]}"; do
  IFS='|' read -r url rel req <<<"$entry"
  download "$url" "$rel" "$req"
done

for entry in "${ANIMATEDIFF_ASSETS[@]}"; do
  IFS='|' read -r url rel req <<<"$entry"
  local_dest="${COMFYUI_DIR}/${rel}"
  local_dest_dir=$(dirname "$local_dest")
  mkdir -p "$local_dest_dir"
  if [[ -s "$local_dest" ]]; then
    warn "Already present → ${rel}"
    summary+=("SKIP exists ${rel}")
    continue
  fi
  tmp="${TEMP_DIR}/$(basename "$rel")"
  info "Downloading ${rel}"
  if curl --fail -L --retry 3 --retry-delay 5 --progress-bar "${HEADER[@]}" -o "$tmp" "$url"; then
    mv "$tmp" "$local_dest"
    ok "Saved ${rel}"
    summary+=("OK ${rel}")
  else
    err "Failed ${rel}"
    summary+=("ERR ${rel}")
    rm -f "$tmp"
  fi

done

rm -rf "$TEMP_DIR"

echo
info "Summary"
printf '  %s\n' "${summary[@]}"
info "Manual installs: use ComfyUI Manager for SDXL ControlNets, upscalers, and AnimateDiff motion LoRAs if needed"
