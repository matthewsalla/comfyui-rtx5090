#!/usr/bin/env bash
# Download FLUX.1 [dev] family + add-ons into workspace/comfyui/models.
# Requirements: python3 with pip. Uses huggingface_hub; installs it if missing.

set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info(){ printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$*"; }
ok(){ printf "%b[OK]%b   %s\n" "$GREEN" "$NC" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$*"; }
err(){ printf "%b[ERR]%b  %s\n" "$RED" "$NC" "$*"; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$SCRIPT_DIR"
TARGET_DIR="${TARGET_DIR:-${REPO_ROOT}/workspace/comfyui/models}"
REVISION="${REVISION:-main}"

HF_TOKEN="${HUGGING_FACE_HUB_TOKEN:-${HF_TOKEN:-}}"
if [[ -z "$HF_TOKEN" && -f "${REPO_ROOT}/.env" ]]; then
  HF_TOKEN=$(awk -F= '/^HF_TOKEN=/{print $2; exit}' "${REPO_ROOT}/.env")
fi
HF_TOKEN="${HF_TOKEN//\"/}"
export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
export TARGET_DIR REVISION

info "Target directory: ${TARGET_DIR}"
if [[ -z "$HF_TOKEN" ]]; then
  warn "No HF token detected. Gated repos (BFL Flux) will be skipped."
fi

mkdir -p "${TARGET_DIR}" || true

python3 - <<'PY'
import os
import sys
import shutil
import subprocess
from pathlib import Path

TARGET_DIR = Path(os.environ["TARGET_DIR"]).resolve()
REVISION = os.environ.get("REVISION", "main")
TOKEN = os.environ.get("HUGGING_FACE_HUB_TOKEN") or None

try:
    import huggingface_hub  # noqa: F401
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "huggingface_hub>=0.23", "hf_transfer>=0.1.6"], stdout=sys.stdout)

from huggingface_hub import snapshot_download  # noqa: E402

try:
    from huggingface_hub.utils import HfHubHTTPError
except Exception:  # pragma: no cover
    from huggingface_hub.errors import HfHubHTTPError

TASKS = [
    {
        "repo": "black-forest-labs/FLUX.1-dev",
        "files": {"flux1-dev.safetensors": "diffusion_models/flux1-dev.safetensors"},
        "requires_token": True,
    },
    {
        "repo": "comfyanonymous/flux_text_encoders",
        "files": {
            "t5xxl_fp16.safetensors": "text_encoders/t5xxl_fp16.safetensors",
            "t5xxl_fp8_e4m3fn.safetensors": "text_encoders/t5xxl_fp8_e4m3fn.safetensors",
            "t5xxl_fp8_e4m3fn_scaled.safetensors": "text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors",
            "clip_l.safetensors": "text_encoders/clip_l.safetensors",
        },
        "requires_token": False,
    },
    {
        "repo": "Comfy-Org/Lumina_Image_2.0_Repackaged",
        "files": {"split_files/vae/ae.safetensors": "vae/ae.safetensors"},
        "requires_token": False,
    },
    {
        "repo": "Comfy-Org/flux1-dev",
        "files": {"flux1-dev-fp8.safetensors": "checkpoints/flux1-dev-fp8.safetensors"},
        "requires_token": False,
    },
    {
        "repo": "black-forest-labs/FLUX.1-Kontext-dev",
        "files": {"flux1-kontext-dev.safetensors": "diffusion_models/flux1-kontext-dev.safetensors"},
        "requires_token": True,
    },
    {
        "repo": "Comfy-Org/flux1-kontext-dev_ComfyUI",
        "files": {"split_files/diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors": "diffusion_models/flux1-dev-kontext_fp8_scaled.safetensors"},
        "requires_token": False,
    },
    {
        "repo": "black-forest-labs/FLUX.1-Fill-dev",
        "files": {"flux1-fill-dev.safetensors": "diffusion_models/flux1-fill-dev.safetensors"},
        "requires_token": True,
    },
    {
        "repo": "black-forest-labs/FLUX.1-Redux-dev",
        "files": {"flux1-redux-dev.safetensors": "style_models/flux1-redux-dev.safetensors"},
        "requires_token": True,
    },
    {
        "repo": "Comfy-Org/sigclip_vision_384",
        "files": {"sigclip_vision_patch14_384.safetensors": "clip_vision/sigclip_vision_patch14_384.safetensors"},
        "requires_token": False,
    },
]

errors = []
downloaded = []

for task in TASKS:
    repo = task["repo"]
    allow = list(task["files"].keys())
    dests = task["files"]
    needs_token = task["requires_token"]

    if needs_token and not TOKEN:
        errors.append(f"[SKIP] {repo}: requires HF token")
        continue

    try:
        snap_path = snapshot_download(
            repo_id=repo,
            revision=REVISION,
            allow_patterns=allow,
            local_dir_use_symlinks=False,
            token=TOKEN if needs_token else None,
        )
        snap_path = Path(snap_path)
        for src_rel, dst_rel in dests.items():
            src = snap_path / src_rel
            dst = TARGET_DIR / dst_rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            if not src.exists():
                errors.append(f"[MISSING] {repo}: {src_rel} not found in snapshot")
                continue
            if dst.exists():
                downloaded.append(f"[SKIP] {dst_rel} (already exists)")
                continue
            shutil.copy2(src, dst)
            downloaded.append(f"[OK] {dst_rel}")
    except HfHubHTTPError as e:
        errors.append(f"[ERROR] {repo}: {e}")
    except Exception as e:
        errors.append(f"[ERROR] {repo}: {e}")

print("\nSummary:")
for line in downloaded:
    print(" ", line)
if not downloaded:
    print("  No new files copied (everything up to date?)")

if errors:
    print("\nIssues:")
    for line in errors:
        print(" ", line)
    if not downloaded:
        sys.exit(2)
PY
