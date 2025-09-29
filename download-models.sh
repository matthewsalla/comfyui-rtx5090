#!/usr/bin/env bash
# Curated downloader for common ComfyUI models.
# Places files under workspace/comfyui/models/* so the container sees them automatically.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){   printf "%b[INFO]%b %s\n"   "$BLUE" "$NC" "$*"; }
ok(){     printf "%b[OK]%b   %s\n"    "$GREEN" "$NC" "$*"; }
warn(){   printf "%b[WARN]%b %s\n"  "$YELLOW" "$NC" "$*"; }
err(){    printf "%b[ERR]%b  %s\n"   "$RED" "$NC" "$*"; }

# --- Configuration ----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_MODELS_DIR="${BASE_MODELS_DIR:-${REPO_ROOT}/workspace/comfyui/models}"
TMP_DIR="${TMP_DIR:-${REPO_ROOT}/.tmp-model-downloads}"
HF_TOKEN="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
if [[ -z "$HF_TOKEN" && -f "${REPO_ROOT}/.env" ]]; then
  HF_TOKEN=$(awk -F= '/^HF_TOKEN=/{print $2; exit}' "${REPO_ROOT}/.env")
fi
HF_TOKEN="${HF_TOKEN//\"/}"

mkdir -p "${BASE_MODELS_DIR}" "${TMP_DIR}"

# Compose curl command with optional Hugging Face token header
curl_download() {
  local url=$1
  local dest=$2
  local filename=$3

  local header=()
  if [[ -n "$HF_TOKEN" ]]; then
    header+=("-H" "Authorization: Bearer ${HF_TOKEN}")
  fi

  local tmp_file="${TMP_DIR}/${filename}"

  if [[ -s "$dest" ]]; then
    warn "${filename} already exists -> ${dest}"
    return 1
  fi

  info "Downloading ${filename}"
  if curl -fL --retry 3 --retry-delay 5 "${header[@]}" -o "$tmp_file" "$url"; then
    if [[ ! -s "$tmp_file" ]]; then
      err "${filename} appears empty after download"
      rm -f "$tmp_file"
      return 2
    fi
    mkdir -p "$(dirname "$dest")"
    mv "$tmp_file" "$dest"
    ok "Saved ${dest}"
    return 0
  else
    err "Failed to download ${filename}"
    rm -f "$tmp_file"
    return 3
  fi
}

# --- Model definitions ------------------------------------------------------
declare -A MODELS
MODELS["sdxl_base"]="https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true|checkpoints/sd_xl_base_1.0.safetensors|token"
MODELS["sdxl_turbo"]="https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0.safetensors?download=true|checkpoints/sd_xl_turbo_1.0.safetensors|token"
MODELS["sd15"]="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors|checkpoints/v1-5-pruned-emaonly.safetensors|"
MODELS["sd15_fp16"]="https://huggingface.co/Comfy-Org/stable-diffusion-v1-5-archive/resolve/main/v1-5-pruned-emaonly-fp16.safetensors?download=true|checkpoints/v1-5-pruned-emaonly-fp16.safetensors|token"
MODELS["controlnet_canny"]="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth|controlnet/control_v11p_sd15_canny.pth|token"
MODELS["controlnet_openpose"]="https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth|controlnet/control_v11p_sd15_openpose.pth|token"
MODELS["wan_diffusion"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|diffusion_models/wan2.2_ti2v_5B_fp16.safetensors|token"
MODELS["wan_vae"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors|vae/wan2.2_vae.safetensors|token"
MODELS["wan_vae_21"]="https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors|vae/wan_2.1_vae.safetensors|token"
MODELS["wan_text_encoder"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors|token"
MODELS["wan_t2v_high"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors|token"
MODELS["wan_t2v_low"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors|token"
MODELS["wan_i2v_high"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors|token"
MODELS["wan_i2v_low"]="https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors|token"

show_menu(){
  cat <<'MENU'
Select models to download:
 1) SDXL Base 1.0
 2) SDXL Turbo
 3) Stable Diffusion 1.5
 4) ControlNet (canny + openpose)
 5) WAN 2.2 core set (diffusion, VAE, text encoder)
 6) WAN 14B extras (high/low noise, i2v/t2v)
 7) WAN 2.1 VAE (compat)
 8) Everything listed above
 0) Exit
MENU
}

process_choice(){
  local key=$1
case "$key" in
    1) download_set sdxl_base ;;
    2) download_set sdxl_turbo ;;
    3) download_set sd15 sd15_fp16 ;;
    4) download_set controlnet_canny controlnet_openpose ;;
    5) download_set wan_diffusion wan_vae wan_text_encoder ;;
    6) download_set wan_t2v_high wan_t2v_low wan_i2v_high wan_i2v_low ;;
    7) download_set wan_vae_21 ;;
    8) download_set sdxl_base sdxl_turbo sd15 sd15_fp16 controlnet_canny controlnet_openpose \
                   wan_diffusion wan_vae wan_text_encoder wan_t2v_high wan_t2v_low \
                   wan_i2v_high wan_i2v_low wan_vae_21 ;;
    0) info "Nothing selected"; exit 0 ;;
    *) warn "Invalid choice"; exit 1 ;;
  esac
}

download_set(){
  local key
  for key in "$@"; do
    local entry=${MODELS[$key]}
    IFS='|' read -r url rel_path requirement <<<"$entry"
    if [[ "$requirement" == "token" && -z "$HF_TOKEN" ]]; then
      warn "Skipping ${rel_path} (requires HF_TOKEN)"
      continue
    fi
    local filename=$(basename "${rel_path}")
    local dest="${BASE_MODELS_DIR}/${rel_path}"
    curl_download "$url" "$dest" "$filename" || true
  done
}

show_menu
read -rp "Choice: " choice
process_choice "$choice"

if [[ -d "$TMP_DIR" ]]; then
  find "$TMP_DIR" -type f -empty -delete || true
  rmdir "$TMP_DIR" 2>/dev/null || true
fi

ok "Downloads completed. Models located under: ${BASE_MODELS_DIR}"
