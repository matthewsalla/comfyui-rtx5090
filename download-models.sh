#!/bin/bash

# Script to download common models for ComfyUI
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to download a model
download_model() {
    local url=$1
    local destination=$2
    local custom_filename=$3
    
    # If no custom filename is provided, use the basename of the URL without query parameters
    if [ -z "$custom_filename" ]; then
        custom_filename=$(basename "$url" | sed 's/\?.*//')
    fi
    
    # Create temp directory for downloads
    mkdir -p tmp_downloads
    
    # Check if the model already exists in the final destination
    if docker run --rm -v "$(pwd)/$destination:/check_dir" busybox ls -la /check_dir 2>/dev/null | grep -q "$custom_filename"; then
        print_warning "Model $custom_filename already exists in $destination, skipping..."
        return
    fi
    
    # Check if we've already downloaded it to the temp folder and it's not empty
    if [ -f "tmp_downloads/$custom_filename" ] && [ -s "tmp_downloads/$custom_filename" ]; then
        print_status "Found previously downloaded $custom_filename in temporary location."
    else
        # Remove empty or corrupted files
        if [ -f "tmp_downloads/$custom_filename" ]; then
            print_warning "Found empty or corrupted $custom_filename. Removing and re-downloading..."
            rm "tmp_downloads/$custom_filename"
        fi
        
        print_status "Downloading $custom_filename to temporary location..."
        wget -q --show-progress "$url" -O "tmp_downloads/$custom_filename"
        
        if [ $? -ne 0 ] || [ ! -s "tmp_downloads/$custom_filename" ]; then
            print_warning "Failed to download $custom_filename or file is empty"
            if [ -f "tmp_downloads/$custom_filename" ]; then
                rm "tmp_downloads/$custom_filename"
            fi
            return
        fi
        print_success "Downloaded $custom_filename successfully!"
    fi
    
    # Create destination directory in container if it doesn't exist
    print_status "Moving $custom_filename to $destination..."
    docker run --rm -v "$(pwd)/tmp_downloads:/src" -v "$(pwd)/$destination:/dst" busybox sh -c "mkdir -p /dst && cp /src/$custom_filename /dst/"
    
    if [ $? -eq 0 ]; then
        print_success "Moved $custom_filename to $destination successfully!"
        rm "tmp_downloads/$custom_filename"
    else
        print_error "Failed to move $custom_filename to $destination"
        print_status "The file is still available in tmp_downloads/$custom_filename"
    fi
}

# Check for Hugging Face token
if [ -z "$HF_TOKEN" ]; then
    print_warning "HF_TOKEN environment variable not set. Some models may not download."
    print_warning "Set it with: export HF_TOKEN=your_huggingface_token"
    print_warning "You can get a token from: https://huggingface.co/settings/tokens"
    echo ""
fi

# Create temporary download directory
mkdir -p tmp_downloads

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
            download_model "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors?download=true" "models/comfyui/checkpoints" "sd_xl_base_1.0.safetensors"
        else
            print_warning "HF_TOKEN not set, skipping SDXL Base 1.0 download"
        fi
        ;;
    2|6)
        # SDXL Turbo
        if [ -n "$HF_TOKEN" ]; then
            download_model "https://huggingface.co/stabilityai/sdxl-turbo/resolve/main/sd_xl_turbo_1.0.safetensors?download=true" "models/comfyui/checkpoints" "sd_xl_turbo_1.0.safetensors"
        else
            print_warning "HF_TOKEN not set, skipping SDXL Turbo download"
        fi
        ;;
    3|6)
        # SD 1.5
        download_model "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" "models/comfyui/checkpoints" "v1-5-pruned-emaonly.safetensors"
        ;;
    4|6)
        # ControlNet models
        if [ -n "$HF_TOKEN" ]; then
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth" "models/comfyui/controlnet"
            download_model "https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_openpose.pth" "models/comfyui/controlnet"
        else
            print_warning "HF_TOKEN not set, skipping ControlNet models download"
        fi
        ;;



    5|6)
        # Wan 2.2 (TI2V 5B) – diffusion + VAE + text-encoder
        print_status "Preparing to download Wan 2.2 (TI2V 5B) model set..."

        # Optional HF header if user exported HF_TOKEN
        HF_HEADER=""
        if [ -n "$HF_TOKEN" ]; then
            HF_HEADER="--header=\"Authorization: Bearer $HF_TOKEN\""
        fi

        # Diffusion model (≈10 GB)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_ti2v_5B_fp16.safetensors" \
          "models/comfyui/diffusion_models" \
          "wan2.2_ti2v_5B_fp16.safetensors"

        # VAE (≈1.4 GB)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/vae/wan2.2_vae.safetensors" \
          "models/comfyui/vae" \
          "wan2.2_vae.safetensors"

        # Wan 2.1 VAE (compatibility for workflows referencing 2.1 VAE)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_Repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors" \
          "models/comfyui/vae" \
          "wan_2.1_vae.safetensors"

        # Text encoder (≈6.7 GB)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
          "models/comfyui/text_encoders" \
          "umt5_xxl_fp8_e4m3fn_scaled.safetensors"

        # ---------- 14 B high/low-noise (optional) ----------
        # Text-to-Video pair (~14 GiB each, fp8-scaled)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors" \
          "models/comfyui/diffusion_models" \
          "wan2.2_t2v_high_noise_14B_fp8_scaled.safetensors"

        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors" \
          "models/comfyui/diffusion_models" \
          "wan2.2_t2v_low_noise_14B_fp8_scaled.safetensors"

        # Image-to-Video pair (~14 GiB each, fp8-scaled)
        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors" \
          "models/comfyui/diffusion_models" \
          "wan2.2_i2v_high_noise_14B_fp8_scaled.safetensors"

        download_model \
          "https://huggingface.co/Comfy-Org/Wan_2.2_ComfyUI_Repackaged/resolve/main/split_files/diffusion_models/wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors" \
          "models/comfyui/diffusion_models" \
          "wan2.2_i2v_low_noise_14B_fp8_scaled.safetensors"

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

# Clean up temporary directory if empty
if [ -z "$(ls -A tmp_downloads)" ]; then
    rmdir tmp_downloads
fi

print_success "Model download complete!"
print_status "You can now start the services with: docker compose up -d"
