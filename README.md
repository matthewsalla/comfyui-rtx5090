# ComfyUI for RTX 5090 (Docker)

A lean, reproducible ComfyUI stack tuned for NVIDIA RTX 5090 (Blackwell) with CUDA 12.9. The repo focuses on orchestration: the container stays generic while all mutable state (code, models, caches, outputs) lives in a bind-mounted `workspace/` on the host.

## Highlights
- **Minimal image** – CUDA 12.9.1, Python 3.12 venv, and PyTorch from the nightly channel by default. Override the exact wheels via build args (`TORCH_VERSION`, `TORCHVISION_VERSION`, `TORCHAUDIO_VERSION`).
- **Safe entrypoint** – clones/updates ComfyUI into `/workspace/comfyui`, ensures model/cache folders exist, and lets you append extra launch flags with `COMFYUI_ARGS`.
- **Flexible tuning** – toggle allocator knobs such as `PYTORCH_CUDA_ALLOC_CONF` or runtime flags without editing the image; just set values in `.env`.
- **Optional wheel builders** – reproducible Dockerfiles + `build-wheels.sh` to compile flash-attn / xFormers wheels that match the exact torch build you ship.
- **Helper workflow** – `manage.sh` handles `.env` defaults, workspace creation/ownership, builds, starts, logs, etc.

> Only ComfyUI is provided. There is no Stable Diffusion WebUI or other front-ends bundled.

---

## Repo layout

```
.
├─ Dockerfile.comfyui               # Runtime image (CUDA 12.9.1, Ubuntu 24.04)
├─ docker-compose.yml               # Single comfyui service on :8188
├─ entrypoint-comfyui.sh            # Runtime bootstrap (clone/update + launch)
├─ manage.sh                        # Lifecycle helper (init/build/start/…)
├─ build-wheels.sh                  # Builds flash-attn / xformers wheels in wheelhouse/
├─ Dockerfile.flash-attn-wheel      # Wheel builder (respects torch build args)
├─ Dockerfile.xformers-wheel        # Wheel builder (respects torch build args)
├─ download-FLUX.sh                 # Optional Flux.1 [dev] model helper
├─ download-models.sh               # Optional common-models helper
├─ wheelhouse/                      # Place prebuilt wheels here (optional)
├─ workspace/                       # Bind-mounted working tree (created on demand)
└─ README.md
```

---

## Prerequisites
- Linux host with an NVIDIA GPU (targeting RTX 5090, 32 GB VRAM).
- NVIDIA driver + NVIDIA Container Toolkit compatible with CUDA 12.9.
- Docker Engine 24+ with the Compose plugin.
- (For gated models) Hugging Face token (`HF_TOKEN`).

---

## Quick start

1. **Bootstrap configuration & workspace**
   ```bash
   ./manage.sh init     # writes .env, creates workspace/, fixes ownership
   ```

2. **(Optional) Pre-build GPU wheels**
   ```bash
   ./build-wheels.sh    # flashes/xformers wheels land in wheelhouse/
   ```

3. **Build & start the stack**
   ```bash
   ./manage.sh build    # docker compose build (uses .env for build args)
   ./manage.sh start    # docker compose up -d
   ./manage.sh logs     # tail ComfyUI logs
   ./manage.sh doctor   # optional: verify bind mounts are writable
   ```

4. **Visit the UI** – http://localhost:8188 (or the host IP).

To stop later: `./manage.sh stop`.

---

## Configuring PyTorch / launch flags

`.env` holds all tunables. Defaults look like:

```
TORCH_CHANNEL=https://download.pytorch.org/whl/nightly/cu129
TORCH_VERSION=
TORCHVISION_VERSION=
TORCHAUDIO_VERSION=
FLASH_ATTN_VERSION=2.8.1
XFORMERS_VERSION=
XFORMERS_REPO=https://github.com/facebookresearch/xformers.git
XFORMERS_REF=main
PYTORCH_CUDA_ALLOC_CONF=
COMFYUI_ARGS=
```

- Leave the version fields blank to pull the latest nightly wheels.
- Pin to a particular build by setting, for example:
  ```
  TORCH_VERSION=2.9.0.dev20250923+cu129
  TORCHVISION_VERSION=0.24.0.dev20250923+cu129
  TORCHAUDIO_VERSION=2.8.0.dev20250923+cu129
  ```
  Then rerun `./manage.sh build`.
- Set `PYTORCH_CUDA_ALLOC_CONF` when you need allocator tweaks (e.g. `backend:cudaMallocAsync,max_split_size_mb:64`).
- Provide extra CLI flags for ComfyUI with `COMFYUI_ARGS` (e.g. `--highvram --force-fp16`). They are appended ahead of any flags you pass to the container command.
- Adjust `FLASH_ATTN_VERSION`, `XFORMERS_VERSION`, `XFORMERS_REPO`, or `XFORMERS_REF` if you need to rebuild custom CUDA wheels. Leave `XFORMERS_VERSION` empty to pull from the specified repo/ref (defaults to `main`).

---

## Workspace layout

All ComfyUI data lives under `workspace/` on the host and is bind-mounted into the container. After the first successful start you’ll see:

```
workspace/
├─ .cache/{pip,hf,torch,xdg}
└─ comfyui/
   ├─ models/
   │  ├─ checkpoints/
   │  ├─ clip/
   │  └─ … (standard ComfyUI subfolders)
   ├─ custom_nodes/
   ├─ config/
   ├─ logs/
   ├─ output/
   └─ .version
```

Drop your models/checkpoints into the respective folders inside `workspace/comfyui/models`. `download-FLUX.sh` and `download-models.sh` can help populate common sets.

`manage.sh doctor` verifies that everything is writable.

---

## Wheel builders (optional)

`build-wheels.sh` compiles flash-attn and xformers in throwaway builder images, using the same torch channel + version pins as the runtime image. The wheels are copied back to `wheelhouse/` as your user (no root-owned artifacts) and are installed automatically during the next `docker compose build` (the Dockerfile checks for wheels before falling back to source builds).

To rebuild wheels after changing torch versions:
```bash
./build-wheels.sh
./manage.sh build
```

Control the wheel builders through `.env`:

```
FLASH_ATTN_VERSION=2.8.1              # set empty to use upstream default build logic
XFORMERS_VERSION=                     # blank → build from XFORMERS_REPO@XFORMERS_REF
XFORMERS_REPO=https://github.com/facebookresearch/xformers.git
XFORMERS_REF=main
```

If `XFORMERS_VERSION` is blank, the builder compiles directly from the repo/ref. Set it to a published version (e.g. `0.0.33.dev20250901+cu129`) to build that exact wheel.

After running `./build-wheels.sh`, rebuild and restart the runtime image so the new wheels are baked in:

```
./manage.sh build
./manage.sh start
./manage.sh logs   # confirm torch/xformers versions at launch
```

---

## Helper commands (`manage.sh`)

```
Usage: ./manage.sh {init|doctor|setup|build|start|stop|restart|status|logs|update|help}
```

- `init` – ensure `.env`, create `workspace/`, fix ownership/permissions.
- `build` – `docker compose build --no-cache` (picks up torch args, wheelhouse, etc.).
- `start` / `stop` / `restart` – lifecycle controls.
- `logs` – follow container logs.
- `doctor` – check that bind mounts are writable.
- `update` – `git pull` the ComfyUI repo inside the container.

You can always fall back to the raw `docker compose` commands if you prefer.

---

## Troubleshooting tips

- **`std::bad_alloc` on startup** – try adjusting `PYTORCH_CUDA_ALLOC_CONF` (e.g. reduce `max_split_size_mb`) or temporarily pin Torch to a known-good build. Use `nvidia-smi -l` while starting to watch VRAM spikes.
- **Permission denied under /workspace** – run `./manage.sh doctor`. If still failing, `sudo chown -R $(id -u):$(id -g) workspace` and start again.
- **Slow dependency installs each boot** – the entrypoint performs a best-effort `pip install -r requirements.txt`. If you prefer frozen deps, bake them into the image or manage a venv inside `workspace/`.
- **Wheel ABI mismatch** – regenerate wheels after changing torch versions so flash-attn/xformers match the pinned torch build.

---

## License

MIT — see `LICENSE`.
