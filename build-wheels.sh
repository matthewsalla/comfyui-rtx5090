#!/usr/bin/env bash
set -euo pipefail

# Minimal wheel builder for flash-attn / xformers aligned with runtime torch

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info(){ printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$*"; }
ok(){ printf "%b[OK]%b   %s\n" "$GREEN" "$NC" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$*"; }

require_file(){ [[ -f "$1" ]] || { warn "$1 missing"; exit 1; }; }

read_env(){
  local key=$1
  if [[ -f .env ]]; then
    awk -F= -v k="$key" '$1==k {print $2; exit}' .env
  fi
}

build_image(){
  local dockerfile=$1
  local tag=$2
  local torch_channel=$3
  local torch_version=$4
  local torchvision_version=$5
  local torchaudio_version=$6
  shift 6 || true
  local extra_args=("$@")

  local args=(
    --build-arg "TORCH_CHANNEL=${torch_channel}"
    --build-arg "TORCH_VERSION=${torch_version}"
    --build-arg "TORCHVISION_VERSION=${torchvision_version}"
    --build-arg "TORCHAUDIO_VERSION=${torchaudio_version}"
  )
  docker build "${args[@]}" "${extra_args[@]}" -f "$dockerfile" -t "$tag" .
}

extract_wheel(){
  local image=$1
  local pattern=$2
  mkdir -p wheelhouse
  local cmd='shopt -s nullglob; files=(/wheelhouse/'"${pattern}"'); if [ ${#files[@]} -eq 0 ]; then echo "No matching files for ${pattern}"; else cp -t /output "${files[@]}"; fi'
  local run_user="$(id -u):$(id -g)"
  docker run --rm --user "$run_user" -v "${PWD}/wheelhouse:/output" "$image" bash -lc "$cmd"
}


main(){
  info "Preparing wheel builders"
  require_file Dockerfile.flash-attn-wheel
  require_file Dockerfile.xformers-wheel

  local torch_channel torch_version torchvision_version torchaudio_version
  torch_channel=$(read_env TORCH_CHANNEL)
  torch_version=$(read_env TORCH_VERSION)
  torchvision_version=$(read_env TORCHVISION_VERSION)
  torchaudio_version=$(read_env TORCHAUDIO_VERSION)
  local flash_attn_version xformers_version xformers_repo xformers_ref
  flash_attn_version=$(read_env FLASH_ATTN_VERSION)
  xformers_version=$(read_env XFORMERS_VERSION)
  xformers_repo=$(read_env XFORMERS_REPO)
  xformers_ref=$(read_env XFORMERS_REF)
  [[ -n "$torch_channel" ]] || torch_channel="https://download.pytorch.org/whl/nightly/cu129"
  [[ -n "$xformers_repo" ]] || xformers_repo="https://github.com/facebookresearch/xformers.git"
  [[ -n "$xformers_ref" ]] || xformers_ref="main"

  local flash_args=()
  if [[ -n "$flash_attn_version" ]]; then
    flash_args+=(--build-arg "FLASH_ATTN_VERSION=${flash_attn_version}")
  fi

  # info "Building flash-attn wheel image"
  # build_image Dockerfile.flash-attn-wheel flash-attn-builder \
  #   "$torch_channel" "$torch_version" "$torchvision_version" "$torchaudio_version" \
  #   "${flash_args[@]}"

  # info "Building xformers wheel image"
  # build_image Dockerfile.xformers-wheel xformers-builder \
  #   "$torch_channel" "$torch_version" "$torchvision_version" "$torchaudio_version" \
  #   --build-arg "XFORMERS_VERSION=${xformers_version}" \
  #   --build-arg "XFORMERS_REPO=${xformers_repo}" \
  #   --build-arg "XFORMERS_REF=${xformers_ref}"

  info "Extracting wheels"
  extract_wheel flash-attn-builder "flash_attn*.whl"
  extract_wheel xformers-builder "xformers*.whl"

  if command -v chown >/dev/null 2>&1; then
    if ! chown -R "$(id -u):$(id -g)" wheelhouse 2>/dev/null; then
      warn "Could not adjust wheelhouse ownership; run: sudo chown -R $(id -u):$(id -g) wheelhouse"
    fi
  fi

  ok "Wheels ready under wheelhouse/"
}

main "$@"
