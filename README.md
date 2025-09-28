# ComfyUI for RTX 5090 (Docker)

A lean, GPU-optimized ComfyUI stack targeting NVIDIA **RTX 5090 (Blackwell)** with CUDA 12.9.
This repo gives you:

* A Docker image for ComfyUI (`Dockerfile.comfyui`) tuned for compute capability 12.0.
* Optional wheel builders for **flash-attn 2.8.1** and **xFormers 0.0.32.dev1073** on CUDA 12.9
  (`Dockerfile.flash-attn-wheel`, `Dockerfile.xformers-wheel`).
* A `docker-compose.yml` with sensible volumes, healthcheck, and port mapping (**8188**).
* Convenience scripts: `manage.sh` (lifecycle helpers), `download-FLUX.sh` (Flux.1 [dev] bundle),
  `download-models.sh` (common ComfyUI model folders), and `build-wheels.sh` (setup + wheel build glue).

> ⚠️ Note: Only ComfyUI is included. There is **no Stable Diffusion WebUI service** in this repository.

---

## What’s inside

```text
.
├─ Dockerfile.comfyui               # ComfyUI base image (CUDA 12.9.1, Ubuntu 24.04)
├─ Dockerfile.flash-attn-wheel      # (optional) build Flash-Attention 2.8.1 wheel
├─ Dockerfile.xformers-wheel        # (optional) build xFormers 0.0.32.dev1073 wheel
├─ docker-compose.yml               # ComfyUI service on :8188 with bind-mounts
├─ entrypoint-comfyui.sh            # Starts ComfyUI with safe defaults
├─ download-FLUX.sh                 # Helper to fetch Flux.1 [dev] + extras into models/comfyui
├─ download-models.sh               # Helper to create/populate common ComfyUI model dirs
├─ build-wheels.sh                  # Wrapper to create folders and build wheels
├─ manage.sh                        # Shortcuts (build/up/down/logs/setup) — optional
├─ LICENSE
└─ README.md
```

## Requirements

* Linux host with an NVIDIA GPU (tested target: **RTX 5090, 32 GB**).
* NVIDIA driver compatible with **CUDA 12.9** and the **NVIDIA Container Toolkit** installed.
* Recent Docker & Docker Compose plugin.
* (For gated model downloads) Hugging Face token: set `HF_TOKEN` or `HUGGING_FACE_HUB_TOKEN`.

## Quick start

1. **Create folders** (if you don’t use `manage.sh setup`):

```bash
mkdir -p models/comfyui custom_nodes config/comfyui logs/comfyui outputs/comfyui
```

2. **(Optional) Download Flux.1 [dev] & friends** into the right ComfyUI folders:

```bash
export HF_TOKEN=hf_xxx    # required for gated BFL repos
./download-FLUX.sh
```

3. **Build and run**:

```bash
docker compose build
docker compose up -d
```

Then open **[http://localhost:8188](http://localhost:8188)** (or the host IP) for ComfyUI.

4. **Tail logs / stop**:

```bash
docker compose logs -f comfyui
docker compose down
```

## Volumes & paths

The Compose file bind-mounts the following to ComfyUI’s workdir (`/workspace/comfyui`):

* `./models/comfyui` → `/workspace/comfyui/models`
* `./custom_nodes`   → `/workspace/comfyui/custom_nodes`
* `./config/comfyui` → `/workspace/comfyui/config`
* `./logs/comfyui`   → `/workspace/comfyui/logs`
* `./outputs/comfyui`→ `/workspace/comfyui/output`

Place your models according to **ComfyUI’s standard layout**, for example:

```text
models/comfyui/
├─ checkpoints/            # .safetensors, .ckpt
├─ clip/
├─ clip_vision/
├─ controlnet/
├─ ipadapter/
├─ loras/
├─ upscale_models/
├─ vae/
└─ (etc. per ComfyUI conventions)
```

The included `download-FLUX.sh` will create the correct subfolders for Flux.1 [dev] pipelines (diffusion, text_encoders, vae, checkpoints, etc.).

## GPU configuration

The image sets `TORCH_CUDA_ARCH_LIST=12.0` for Blackwell. Make sure Docker is allowed to access your GPU.
If your Compose engine doesn’t auto-detect GPUs, add one of the following to the `comfyui` service:

**Compose v2 GPU flag:**

```yaml
deploy:
  resources:
    reservations:
      devices:
        - capabilities: ["gpu"]
```

**Or the older syntax:**

```yaml
runtime: nvidia
environment:
  - NVIDIA_VISIBLE_DEVICES=all
```

> Your `docker-compose.yml` already maps port **8188** and includes a simple HTTP healthcheck.

## Optional: build flash-attn / xFormers wheels

For maximum control you can prebuild wheels matched to the CUDA/PyTorch used in the image:

```bash
# Flash-Attention
docker build -f Dockerfile.flash-attn-wheel -t flashattn-cu129 .
CID=$(docker create flashattn-cu129)
mkdir -p wheels/flash-attn && docker cp "$CID":/wheelhouse ./wheels/flash-attn && docker rm "$CID"

# xFormers
docker build -f Dockerfile.xformers-wheel -t xformers-cu129 .
CID=$(docker create xformers-cu129)
mkdir -p wheels/xformers && docker cp "$CID":/wheelhouse ./wheels/xformers && docker rm "$CID"
```

To use these, either rebuild your ComfyUI image and `pip install` the wheels inside the Dockerfile,
or exec into a running container and install them:

```bash
docker compose exec comfyui bash -lc "pip install /workspace/wheels/flash-attn/*.whl /workspace/wheels/xformers/*.whl"
```

(You can mount `./wheels` into the container by adding another bind-mount in `docker-compose.yml`.)

## Convenience script (optional)

A small helper is provided to streamline common actions:

```bash
./manage.sh setup     # create folders
./manage.sh build     # docker compose build
./manage.sh up        # docker compose up -d
./manage.sh down      # docker compose down
./manage.sh logs      # tail ComfyUI logs
```

> If any of these subcommands are missing on your copy, just use the equivalent `docker compose …` commands above.

## Updating

* Pull the latest repo changes.
* Rebuild the image: `docker compose build --no-cache`.
* Restart: `docker compose up -d`.

## Troubleshooting

* **Container can’t see the GPU** → verify NVIDIA drivers, the NVIDIA Container Toolkit, and that Compose is configured to pass the GPU through (see *GPU configuration* above).
* **Model not found / wrong folder** → confirm the file is under the correct `models/comfyui/**` subfolder name used by your ComfyUI node.
* **Out-of-memory** → try lower-VRAM workflows, disable high-VRAM nodes, or reduce image sizes/batch counts.
* **Slow first run** → the image may compile kernels on first use; subsequent runs are faster.

## License

MIT — see `LICENSE`.
