#!/usr/bin/env bash
# Download FLUX.1 [dev] + extras for ComfyUI into ./models/comfyui using Hugging Face Hub.
# Includes:
#   - Full "regular" Flux Dev pipeline (diffusion + text encoders + VAE)
#   - Single-file FP8 checkpoint (easy mode)
#   - Kontext (editing), Fill (in/outpainting), Redux (multi-image prompting) + SIGLIP-Vision
#
# Usage:
#   export HF_TOKEN=hf_xxx   # or HUGGING_FACE_HUB_TOKEN=hf_xxx (required for BFL gated repos)
#   ./download-FLUX.sh
#
# Requires: Python 3.9+

set -euo pipefail

# Root destination for ComfyUI models
DEST_DIR="${DEST_DIR:-models/comfyui}"
REVISION="${REVISION:-main}"

echo ">>> Target ComfyUI models dir: ${DEST_DIR}"
echo ">>> Revision: ${REVISION}"
echo

# Warn if token missing (BFL repos are gated)
if [[ -z "${HUGGING_FACE_HUB_TOKEN:-${HF_TOKEN:-}}" ]]; then
  echo "!! No HF token detected (HUGGING_FACE_HUB_TOKEN / HF_TOKEN)."
  echo "   FLUX.1 [dev] + Redux/Kontext/Fill are gated by Black Forest Labs."
  echo "   Accept the license and set a token or the script will skip those files."
  echo
fi

# Resolve paths (pattern: repo root is parent of this script)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${ROOT_DIR}/${DEST_DIR}"

# Required subfolders for ComfyUI
mkdir -p \
  "${TARGET_DIR}/diffusion_models" \
  "${TARGET_DIR}/text_encoders" \
  "${TARGET_DIR}/vae" \
  "${TARGET_DIR}/checkpoints" \
  "${TARGET_DIR}/style_models" \
  "${TARGET_DIR}/clip_vision"

# Minimal venv to avoid polluting system Python
VENV_DIR="${ROOT_DIR}/.venv-hf"
if [[ ! -d "${VENV_DIR}" ]]; then
  echo ">>> Creating venv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

# Faster downloads if available
export HF_HUB_ENABLE_HF_TRANSFER=1

python -m pip install -q --upgrade pip
python -m pip install -q "huggingface_hub[cli]>=0.23.0" "hf_transfer>=0.1.6" || true

echo ">>> Starting downloads… (this can take a while)"
echo

# Export the vars so the heredoc can read them
export TARGET_DIR REVISION
# Surface either token name to Python
export HUGGING_FACE_HUB_TOKEN="${HUGGING_FACE_HUB_TOKEN:-${HF_TOKEN:-}}"

python - <<'PY'
import os, sys, shutil
from pathlib import Path
from huggingface_hub import snapshot_download

# --- compat shim for HfHubHTTPError across versions ---
try:
    from huggingface_hub.utils._errors import HfHubHTTPError  # newer
except Exception:  # pragma: no cover
    try:
        from huggingface_hub.errors import HfHubHTTPError    # older
    except Exception:
        class HfHubHTTPError(Exception):                      # fallback
            pass
# ------------------------------------------------------

BASE = Path(os.environ["TARGET_DIR"]).resolve()
rev  = os.environ.get("REVISION","main")
tok  = os.environ.get("HUGGING_FACE_HUB_TOKEN") or os.environ.get("HF_TOKEN")

def copy_from_snapshot(snap_dir: Path, rel_src: str, dest_rel: str):
    src = snap_dir / rel_src
    dst = BASE / dest_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not src.exists():
        raise FileNotFoundError(f"Missing '{rel_src}' in snapshot {snap_dir}")
    shutil.copy2(src, dst)
    print(f"[OK] {dest_rel}")

TASKS = [
    # Full "regular" Flux Dev diffusion weights (gated)
    {
      "repo": "black-forest-labs/FLUX.1-dev",
      "allow": ["flux1-dev.safetensors"],
      "copies": {
        "flux1-dev.safetensors": "diffusion_models/flux1-dev.safetensors",
      },
      "gated": True,
    },
    # Text encoders (public)
    {
      "repo": "comfyanonymous/flux_text_encoders",
      "allow": ["t5xxl_fp16.safetensors","t5xxl_fp8_e4m3fn.safetensors","t5xxl_fp8_e4m3fn_scaled.safetensors","clip_l.safetensors"],
      "copies": {
        "t5xxl_fp16.safetensors":         "text_encoders/t5xxl_fp16.safetensors",
        "t5xxl_fp8_e4m3fn.safetensors":   "text_encoders/t5xxl_fp8_e4m3fn.safetensors",
        "t5xxl_fp8_e4m3fn_scaled.safetensors":"text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors",
        "clip_l.safetensors":             "text_encoders/clip_l.safetensors",
      },
      "gated": False,
    },
    # VAE (public)
    {
      "repo": "Comfy-Org/Lumina_Image_2.0_Repackaged",
      "allow": ["split_files/vae/ae.safetensors"],
      "copies": {
        "split_files/vae/ae.safetensors": "vae/ae.safetensors",
      },
      "gated": False,
    },
    # FP8 single-file checkpoint (public, easy mode)
    {
      "repo": "Comfy-Org/flux1-dev",
      "allow": ["flux1-dev-fp8.safetensors"],
      "copies": {
        "flux1-dev-fp8.safetensors": "checkpoints/flux1-dev-fp8.safetensors",
      },
      "gated": False,
    },
    # Kontext (editing) full dev (gated)
    {
      "repo": "black-forest-labs/FLUX.1-Kontext-dev",
      "allow": ["flux1-kontext-dev.safetensors"],
      "copies": {
        "flux1-kontext-dev.safetensors": "diffusion_models/flux1-kontext-dev.safetensors",
      },
      "gated": True,
    },
    # Kontext FP8 scaled (public helper mirror)
    {
      "repo": "Comfy-Org/flux1-kontext-dev_ComfyUI",
      "allow": ["split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors"],
      "copies": {
        "split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors": "diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors",
      },
      "gated": False,
    },
    # Fill (inpainting/outpainting) full dev (gated)
    {
      "repo": "black-forest-labs/FLUX.1-Fill-dev",
      "allow": ["flux1-fill-dev.safetensors"],
      "copies": {
        "flux1-fill-dev.safetensors": "diffusion_models/flux1-fill-dev.safetensors",
      },
      "gated": True,
    },
    # Redux style model (gated)
    {
      "repo": "black-forest-labs/FLUX.1-Redux-dev",
      "allow": ["flux1-redux-dev.safetensors"],
      "copies": {
        "flux1-redux-dev.safetensors": "style_models/flux1-redux-dev.safetensors",
      },
      "gated": True,
    },
    # SIGLIP Vision backbone for Redux (public)
    {
      "repo": "Comfy-Org/sigclip_vision_384",
      "allow": ["sigclip_vision_patch14_384.safetensors"],
      "copies": {
        "sigclip_vision_patch14_384.safetensors": "clip_vision/sigclip_vision_patch14_384.safetensors",
      },
      "gated": False,
    },
]

errors = []
downloaded = []

for t in TASKS:
    repo = t["repo"]
    allow = t["allow"]
    copies = t["copies"]
    gated = t["gated"]
    try:
        snap = snapshot_download(
            repo_id=repo,
            revision=rev,
            allow_patterns=allow,
            local_dir_use_symlinks=False,
            token=tok if gated else None,
        )
        snap_path = Path(snap)
        for rel_src, rel_dst in copies.items():
            try:
                copy_from_snapshot(snap_path, rel_src, rel_dst)
                downloaded.append(rel_dst)
            except Exception as e:
                errors.append(f"[ERROR] {repo}: {e}")
    except HfHubHTTPError as e:
        if gated and not tok:
            errors.append(f"[ERROR] {repo}: gated; no token provided or license not accepted.")
        else:
            errors.append(f"[ERROR] {repo}: {e}")
    except Exception as e:
        errors.append(f"[ERROR] {repo}: {e}")

# Minimal sanity: at least one of (full diffusion OR fp8 checkpoint) should exist
have_full = (BASE / "diffusion_models/flux1-dev.safetensors").exists()
have_fp8  = (BASE / "checkpoints/flux1-dev-fp8.safetensors").exists()
if not (have_full or have_fp8):
    errors.append("[ERROR] Neither full Flux Dev (diffusion_models/flux1-dev.safetensors) nor FP8 checkpoint (checkpoints/flux1-dev-fp8.safetensors) is present.")

print("\n>>> Summary:")
for p in downloaded:
    print("   -", p)

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(2)
PY

echo
echo ">>> Contents:"
find "${TARGET_DIR}" -maxdepth 2 -type f \( \
  -name "flux1-*.safetensors" -o \
  -name "t5xxl_*.safetensors" -o \
  -name "clip_l.safetensors" -o \
  -name "sigclip_vision_patch14_384.safetensors" -o \
  -name "ae.safetensors" \
\) -printf "   - %P (%k KB)\n" || true

echo
echo "ℹ️  Notes:"
echo "   - Full pipeline uses: diffusion_models/flux1-dev.safetensors + text_encoders/{t5xxl_*,clip_l}.safetensors + vae/ae.safetensors"
echo "   - FP8 single-file: checkpoints/flux1-dev-fp8.safetensors (use Load Checkpoint; set CFG=1.0)"
echo "   - Kontext/Fill in diffusion_models, Redux in style_models, SIGLIP in clip_vision"
echo
echo "✅ Done. Files placed under: ${TARGET_DIR}"
