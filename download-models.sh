#!/bin/bash

# Script to download common models for ComfyUI and Stable Diffusion
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to download a model
download_model() {
    local url=$1
    local destination=$2
    local filename=$(basename "$url")
    
    if [ -f "$destination/$filename" ]; then
        print_warning "Model $filename already exists in $destination, skipping..."
        return
    fi
    
    print_status "Downloading $filename to $destination..."
    mkdir -p "$destination"
    wget -q --show-progress "$url" -P "$destination"
    
    if [ $? -eq 0 ]; then
        print_success "Downloaded $filename successfully!"
    else
        print_warning "Failed to download $filename"
    fi
}

# Check for Hugging Face token
if [ -z "$HF_TOKEN" ]; then
    print_warning "HF_TOKEN environment variable not set. Some models may not download."
    print_warning "Set it with: export HF_TOKEN=your_huggingface_token"
    print_warning "You can get a token from: https://huggingface.co/settings/tokens"
    echo ""
fi

# Create directory structure if it doesn't exist
mkdir -p models/{comfyui,stable-diffusion}
mkdir -p models/comfyui/{checkpoints,loras,vae,controlnet,clip}
mkdir -p models/stable-diffusion/{Stable-diffusion,VAE,Lora,ControlNet,CLIP}

# Ask which models to download
echo "Which models would you like to download?"
echo "1) SDXL Base 1.0"
echo "2) SDXL Turbo"
echo "3) Stable Diffusion 1.5"
echo "4) ControlNet models"
echo "5) WAN Tagger models"
echo "6) All of the above"
echo "0) None/Exit"

read -p "Enter your choice (0-6): " choice

case $choice in
    1|6)
        # SDXL Base 1.0
        if [ -n "$HF_TOKEN" ]; then
            download_model "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true" "models/comfyui/checkpoints"
            download_model "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true" "models/stable-diffusion/Stable-diffusion"
        else
            print_warning "HF_TOKEN not set, skipping SDXL Base 1.0 download"
        fi
        ;;
    2|6)
        # SDXL Turbo
        if [ -n "$HF_TOKEN" ]; then
            download_model "https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0.safetensors?download=true" "models/comfyui/checkpoints"
            download_model "https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0.safetensors?download=true" "models/stable-diffusion/Stable-diffusion"
        else
            print_warning "HF_TOKEN not set, skipping SDXL Turbo download"
        fi
        ;;
    3|6)
        # SD 1.5
        download_model "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" "models/comfyui/checkpoints"
        download_model "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" "models/stable-diffusion/Stable-diffusion"
        ;;
    4|6)
        # ControlNet models
        if [ -n "$HF_TOKEN" ]; then
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth" "models/comfyui/controlnet"
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth" "models/comfyui/controlnet"
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth" "models/stable-diffusion/ControlNet"
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth" "models/stable-diffusion/ControlNet"
        else
            print_warning "HF_TOKEN not set, skipping ControlNet models download"
        fi
        ;;
    5|6)
        # WAN Tagger models
        download_model "https://github.com/toriato/stable-diffusion-webui-wd14-tagger/releases/download/v2.2/wd14_tagger_model.zip" "/tmp"
        if [ -f "/tmp/wd14_tagger_model.zip" ]; then
            print_status "Extracting WAN Tagger model..."
            mkdir -p "models/comfyui/WD14Tagger"
            unzip -o "/tmp/wd14_tagger_model.zip" -d "models/comfyui/WD14Tagger"
            rm "/tmp/wd14_tagger_model.zip"
            print_success "WAN Tagger model extracted!"
        fi
        ;;
    0)
        print_status "Exiting without downloading any models."
        exit 0
        ;;
    *)
        print_warning "Invalid choice. Exiting."
        exit 1
        ;;
esac

print_success "Model download complete!"
print_status "You can now start the services with: docker-compose up -d"