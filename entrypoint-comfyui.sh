#!/bin/bash
set -e

# Current date for version pinning
CURRENT_DATE=$(date +"%Y-%m-%d")
COMFYUI_VERSION="comfyui-nightly-${CURRENT_DATE}"

# Set HOME to a writable location
export HOME=/workspace
export PIP_CACHE_DIR=/workspace/.cache/pip

# Configure git
git config --global --add safe.directory /workspace/comfyui
git config --global url."https://github.com/".insteadOf git://github.com/
git config --global http.timeout 300

# Create necessary directories
mkdir -p /workspace/comfyui/models/checkpoints
mkdir -p /workspace/comfyui/models/loras
mkdir -p /workspace/comfyui/models/clip
mkdir -p /workspace/comfyui/models/clip_vision
mkdir -p /workspace/comfyui/models/controlnet
mkdir -p /workspace/comfyui/models/upscale_models
mkdir -p /workspace/comfyui/models/vae
mkdir -p /workspace/comfyui/models/embeddings
mkdir -p /workspace/comfyui/models/unet
mkdir -p /workspace/comfyui/custom_nodes
mkdir -p /workspace/.cache/pip

# Check if version file exists
if [ -f "/workspace/comfyui/.version" ]; then
  EXISTING_VERSION=$(cat /workspace/comfyui/.version)
  echo "Current ComfyUI version: $EXISTING_VERSION"
else
  EXISTING_VERSION=""
  echo "No existing version found, will pin to current nightly"
fi

# Pin to current nightly if no version exists
if [ "$EXISTING_VERSION" == "" ]; then
  cd /workspace/comfyui
  
  # Get current commit hash
  git pull
  COMMIT_HASH=$(git rev-parse HEAD)
  
  # Save version information
  echo "${COMFYUI_VERSION} (${COMMIT_HASH})" > /workspace/comfyui/.version
  echo "Pinned ComfyUI to version: ${COMFYUI_VERSION} (${COMMIT_HASH})"
else
  echo "Using existing pinned version: $EXISTING_VERSION"
fi

# Install any additional dependencies
pip install -r requirements.txt

# Skip extension installation due to network issues
echo "Skipping extension installation due to network connectivity issues"

# Create empty directories for extensions to prevent errors
mkdir -p /workspace/comfyui/custom_nodes/ComfyUI-WD14-Tagger
mkdir -p /workspace/comfyui/custom_nodes/ComfyUI-SDXL-Turbo
mkdir -p /workspace/comfyui/custom_nodes/ComfyUI-Impact-Pack

# Start ComfyUI with optimizations for RTX 5090
cd /workspace/comfyui
exec python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --enable-cors-header \
  --cuda-device 0 \
  --highvram \
  --force-fp16 \
  "$@"