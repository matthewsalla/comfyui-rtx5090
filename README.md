# ComfyUI + Stable Diffusion for RTX 5090

This repository contains a Docker-based deployment solution for running ComfyUI and Stable Diffusion WebUI optimized for NVIDIA RTX 5090 GPUs with 32GB VRAM.

## Features

- Latest CUDA 12.9.1 with pinned PyTorch nightly builds
- Flash Attention 2.8.1 support (pinned version)
- xFormers 0.0.32.dev1073 memory-efficient attention (pinned version)
- WAN 2.2 tagger integration for ComfyUI (pinned to commit hash)
- Version pinning for all components (ComfyUI, Stable Diffusion WebUI, extensions)
- Optimized for maximum performance on RTX 5090 GPUs
- Shared model storage for both ComfyUI and Stable Diffusion

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/comfyui-rtx5090.git
   cd comfyui-rtx5090
   ```

2. Build the optimized wheels (optional but recommended):
   ```bash
   chmod +x build-wheels.sh
   ./build-wheels.sh
   ```

3. Start the services:
   ```bash
   docker-compose up -d
   ```

4. Access the interfaces:
   - ComfyUI: http://localhost:8188
   - Stable Diffusion WebUI: http://localhost:7860

## Directory Structure

```
.
├── models/
│   ├── comfyui/           # ComfyUI models
│   └── stable-diffusion/  # Stable Diffusion models
├── config/
│   ├── comfyui/           # ComfyUI configuration
│   └── stable-diffusion/  # Stable Diffusion configuration
├── logs/
│   ├── comfyui/           # ComfyUI logs
│   └── stable-diffusion/  # Stable Diffusion logs
├── outputs/
│   ├── comfyui/           # ComfyUI generated images
│   └── stable-diffusion/  # Stable Diffusion generated images
├── custom_nodes/          # ComfyUI custom nodes/extensions
├── extensions/            # Stable Diffusion extensions
└── wheelhouse/            # Pre-built optimized wheels
```

## Model Management

Place your models in the appropriate directories:

- Stable Diffusion models: `models/stable-diffusion/Stable-diffusion/`
- VAE models: `models/stable-diffusion/VAE/`
- LoRA models: `models/stable-diffusion/Lora/`
- Embeddings: `models/stable-diffusion/embeddings/`

For ComfyUI:
- Checkpoints: `models/comfyui/checkpoints/`
- LoRAs: `models/comfyui/loras/`
- VAEs: `models/comfyui/vae/`
- Controlnet: `models/comfyui/controlnet/`

## Implementation Details

### Chunk 1: ComfyUI and Stable Diffusion Deployment

The current implementation includes:
- Optimized Docker containers for both ComfyUI and Stable Diffusion
- Pre-built wheels for Flash Attention 2.8.1 and xFormers 0.0.32.dev1073
- Version pinning for all components (ComfyUI, Stable Diffusion WebUI, PyTorch)
- Shared volume mounts for models and outputs

### Chunk 2: WAN 2.2 Integration

WAN 2.2 is integrated as a custom node in ComfyUI. It's automatically installed during container startup.

### Chunk 3: Performance Optimizations

- Flash Attention 2 for faster attention computation
- xFormers for memory-efficient attention
- PyTorch nightly builds with CUDA 12.9.1 support
- High VRAM utilization settings for 32GB GPUs

## Troubleshooting

If you encounter issues:

1. Check the logs:
   ```bash
   docker-compose logs -f comfyui
   docker-compose logs -f stable-diffusion
   ```

2. Ensure your NVIDIA drivers are up to date and support CUDA 12.9

3. If the containers fail to start, try rebuilding them:
   ```bash
   docker-compose build --no-cache
   ```

## License

This project is licensed under the MIT License - see the LICENSE file for details.