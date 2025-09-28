#!/bin/bash

# Unified Wheel Builder Script for RTX 5090
# Builds Flash Attention and xFormers wheels optimized for CUDA 12.9
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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -a, --all            Build all wheels (Flash Attention, xFormers) (default)"
    echo ""
    echo "Examples:"
    echo "  $0                   # Build all wheels (default)"
    echo "  $0 --all            # Build all wheels"
    echo ""
}

# Function to build all wheels
build_all_wheels() {
    print_status "Building all wheels for RTX 5090 with CUDA 12.9..."
    
    # Check if wheel builders exist
    if [ ! -f "Dockerfile.flash-attn-wheel" ]; then
        print_warning "Dockerfile.flash-attn-wheel not found, creating from template"
        cat > Dockerfile.flash-attn-wheel << 'EOL'
# ---------- Flash Attention wheel builder with PyTorch nightly ----------
FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04

# Install Python 3.12 and dev tools
RUN apt-get update && apt-get install -y \
    python3 python3-venv python3-dev \
    gcc-12 g++-12 cmake ninja-build wget git tmux

# Create venv with Python 3.12
RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH \
    TORCH_CUDA_ARCH_LIST="12.0" \
    MAX_JOBS=6 \
    MAKEFLAGS="-j6" \
    CMAKE_BUILD_PARALLEL_LEVEL=6

# Upgrade pip and install build tools
RUN pip install --upgrade pip wheel setuptools

# Install PyTorch nightly (same version as runtime)
RUN pip install --index-url https://download.pytorch.org/whl/nightly/cu129 torch torchvision torchaudio

# Verify PyTorch version
RUN python3 -c "import torch; print('PyTorch version:', torch.__version__)"

# Build Flash Attention wheel with PyTorch nightly (force from source)
# Pin Flash Attention version
ENV FLASH_ATTN_VERSION=2.8.1
RUN pip wheel --no-binary=:all: --no-deps --no-build-isolation --no-cache-dir flash-attn==${FLASH_ATTN_VERSION} -w /wheelhouse \
    && echo "flash-attn-${FLASH_ATTN_VERSION}" > /wheelhouse/flash-attn-version.txt

# List the built wheel
RUN ls -la /wheelhouse/

# Show wheel metadata to verify torch dependency
RUN pip show flash-attn || echo "flash-attn not installed, checking wheel metadata..."

# Wheel is ready in /wheelhouse/ for extraction

# Keep container running for inspection
CMD ["/bin/bash"]
EOL
    fi
    
    if [ ! -f "Dockerfile.xformers-wheel" ]; then
        print_warning "Dockerfile.xformers-wheel not found, creating from template"
        cat > Dockerfile.xformers-wheel << 'EOL'
# ---------- xformers wheel builder with PyTorch nightly ----------
FROM nvidia/cuda:12.9.1-cudnn-devel-ubuntu24.04

# Install Python 3.12 and dev tools
RUN apt-get update && apt-get install -y \
    python3 python3-venv python3-dev \
    gcc-12 g++-12 cmake ninja-build wget git tmux

# Create venv with Python 3.12
RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH \
    TORCH_CUDA_ARCH_LIST="12.0" \
    MAX_JOBS=6 \
    MAKEFLAGS="-j6" \
    CMAKE_BUILD_PARALLEL_LEVEL=6

# Upgrade pip and install build tools
RUN pip install --upgrade pip wheel setuptools

# Install PyTorch nightly (same version as runtime)
RUN pip install --index-url https://download.pytorch.org/whl/nightly/cu129 torch torchvision torchaudio

# Verify PyTorch version
RUN python3 -c "import torch; print('PyTorch version:', torch.__version__)"

# Build xformers wheel with PyTorch nightly (force from source)
# Pin xFormers version
ENV XFORMERS_VERSION=0.0.32.dev1073
RUN pip wheel --no-binary=:all: --no-deps --no-build-isolation --no-cache-dir xformers==${XFORMERS_VERSION} -w /wheelhouse \
    && echo "xformers-${XFORMERS_VERSION}" > /wheelhouse/xformers-version.txt

# List the built wheel
RUN ls -la /wheelhouse/

# Show wheel metadata to verify torch dependency
RUN pip show xformers || echo "xformers not installed, checking wheel metadata..."

# Wheel is ready in /wheelhouse/ for extraction

# Keep container running for inspection
CMD ["/bin/bash"]
EOL
    fi
    
    print_status "Building Flash Attention wheel..."
    docker build -f Dockerfile.flash-attn-wheel -t flash-attn-builder .
    
    print_status "Building xFormers wheel..."
    docker build -f Dockerfile.xformers-wheel -t xformers-builder .
    
    print_status "Extracting all wheels to wheelhouse..."
    mkdir -p wheelhouse
    
    # Extract wheels if containers exist
    if docker images | grep -q "flash-attn-builder"; then
        print_status "Extracting Flash Attention wheel..."
        docker run --rm -v $(pwd)/wheelhouse:/output flash-attn-builder \
            bash -c "cp /wheelhouse/flash_attn*.whl /output/ 2>/dev/null || echo 'No Flash Attention wheel found'"
    fi
    
    if docker images | grep -q "xformers-builder"; then
        print_status "Extracting xFormers wheel..."
        docker run --rm -v $(pwd)/wheelhouse:/output xformers-builder \
            bash -c "cp /wheelhouse/xformers*.whl /output/ 2>/dev/null || echo 'No xFormers wheel found'"
    fi
    
    print_success "All wheels extracted!"
}

# Function to show wheelhouse summary
show_wheelhouse_summary() {
    if [ -d "wheelhouse" ]; then
        echo ""
        print_status "=== Wheelhouse Summary ==="
        echo "Total wheels: $(ls wheelhouse/ | wc -l)"
        echo "Size: $(du -sh wheelhouse/ | cut -f1)"
        echo ""
        echo "Key wheels:"
        ls wheelhouse/ | grep -E "(flash|xformers)" | sort || echo "No key wheels found"
        echo ""
        print_success "Wheels are ready in wheelhouse/ directory!"
    else
        print_warning "No wheelhouse directory found"
    fi
}

# Main script
main() {
    echo "🚀 RTX 5090 Wheel Builder Script"
    echo "================================"
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -a|--all)
                # Default behavior, no change needed
                shift
                ;;
            *)
                print_warning "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Build all wheels (default behavior)
    build_all_wheels
    
    # Show summary
    show_wheelhouse_summary
    
    # Create directory structure
    print_status "Creating directory structure..."
    mkdir -p models/{comfyui,stable-diffusion}
    mkdir -p config/{comfyui,stable-diffusion}
    mkdir -p logs/{comfyui,stable-diffusion}
    mkdir -p outputs/{comfyui,stable-diffusion}
    mkdir -p custom_nodes
    mkdir -p extensions
    
    print_success "Setup complete! You can now run 'docker-compose up -d' to start the services."
}

# Run main function
main "$@"