# Vitis AI 3.5 — Rebuilt for Reliable GPU Docker Builds

This is a fork of [AMD/Xilinx Vitis AI](https://github.com/Xilinx/Vitis-AI) (v3.5, branch `master`) with fixes to make the GPU Docker builds (TensorFlow 2 and PyTorch) work reliably on modern systems.

The upstream build scripts had several issues — broken mamba versions, network failures with no retries, shell logic bugs — that caused builds to fail intermittently or outright. This fork patches those scripts so `docker_build.sh` completes successfully without manual intervention.

## Prerequisites

- **OS**: Ubuntu 20.04+ (tested on 22.04)
- **Docker**: 20.10+ with BuildKit enabled
- **NVIDIA GPU**: CUDA-capable GPU with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed
- **Disk space**: ~40 GB free for GPU images
- **Network**: Stable internet (scripts download ~5 GB of packages)

Verify your setup:

```bash
docker --version
nvidia-smi
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu20.04 nvidia-smi
```

## Quick Start

### 1. Clone

```bash
git clone https://github.com/w958292389/Vitis_ai_3.5_rebuilt.git
cd Vitis_ai_3.5_rebuilt
```

### 2. Build

```bash
cd docker

# Build GPU + TensorFlow 2
yes | ./docker_build.sh -t gpu -f tf2 2>&1 | tee build_gpu_tf2.log

# Build GPU + PyTorch
yes | ./docker_build.sh -t gpu -f pytorch 2>&1 | tee build_gpu_pytorch.log
```

> `yes |` auto-accepts the license prompts. Pipe to `tee` to save build logs.

#### Blackwell GPU (RTX PRO 4000 / RTX 5xxx)

For NVIDIA Blackwell GPUs (sm_120 / compute capability 12.0), use the dedicated CUDA 12.8 build:

```bash
cd docker
bash build_tf2_cuda12.sh 2>&1 | tee build_tf2_cuda12.8.log
```

This builds `xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-cuda12.8` with TF 2.13.1 and GPU support via PTX JIT compilation. Note: the first GPU computation will take ~30 minutes for kernel compilation, after which kernels are cached.

The build produces two stages:
1. **Base image** (conda + system packages): `xilinx/vitis-ai-gpu-<fw>-base:latest`
2. **Final image** (framework + Vitis AI tools): `xilinx/vitis-ai-<framework>-gpu:<version>-<git_hash>`

To skip rebuilding the base image on subsequent runs:

```bash
yes | ./docker_build.sh -t gpu -f tf2 -s
```

### 3. Run

From the repo root:

```bash
# Run PyTorch GPU container
./docker_run.sh xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678

# Run TensorFlow 2 GPU container
./docker_run.sh xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-d251f3678
```

This drops you into a bash shell inside the container with:
- `/workspace` mounted to the repo root
- GPU access via `--gpus all` (auto-detected)
- Your user UID/GID passed through

#### Run options

```bash
# Enable X11 forwarding for GUI apps
./docker_run.sh -X xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678

# Mount a different workspace
./docker_run.sh -w /path/to/project xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678

# Run a specific command instead of bash
./docker_run.sh xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678 python my_script.py

# Run in detached mode
./docker_run.sh -d xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678

# Add extra volume mounts or environment variables
./docker_run.sh -v /data:/data -e MY_VAR=value xilinx/vitis-ai-pytorch-gpu:3.5.0.001-d251f3678
```

#### List available images

```bash
./docker_run.sh --help
```

## Build Matrix

| Type | Framework | Build command | Image tag |
|------|-----------|---------------|-----------|
| GPU  | TF2 (Blackwell) | `bash build_tf2_cuda12.sh` | `xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-cuda12.8` |
| GPU  | TensorFlow 2 | `./docker_build.sh -t gpu -f tf2` | `xilinx/vitis-ai-tensorflow2-gpu:<ver>` |
| GPU  | PyTorch | `./docker_build.sh -t gpu -f pytorch` | `xilinx/vitis-ai-pytorch-gpu:<ver>` |
| GPU  | TensorFlow 1.15 | `./docker_build.sh -t gpu -f tf1` | `xilinx/vitis-ai-tensorflow-gpu:<ver>` |
| CPU  | TensorFlow 2 | `./docker_build.sh -t cpu -f tf2` | `xilinx/vitis-ai-tensorflow2-cpu:<ver>` |
| CPU  | PyTorch | `./docker_build.sh -t cpu -f pytorch` | `xilinx/vitis-ai-pytorch-cpu:<ver>` |
| ROCm | TensorFlow 2 | `./docker_build.sh -t rocm -f tf2` | `xilinx/vitis-ai-tensorflow2-rocm:<ver>` |
| ROCm | PyTorch | `./docker_build.sh -t rocm -f pytorch` | `xilinx/vitis-ai-pytorch-rocm:<ver>` |

> All build commands should be run from the `docker/` directory.

## What Was Changed

Five files in `docker/` were modified. Three of them are shared across all build types, so CPU and ROCm builds also benefit.

### 1. `docker/common/install_conda.sh` — Mamba version pinning

The original Mambaforge ships mamba 0.15.3 (2021), which cannot parse current conda-forge repodata. Updating to mamba 2.x breaks the `--no-update-deps` flag used throughout install scripts.

**Fix**: Pin mamba to `>=1.5,<2` after Mambaforge installation. Also added wget retry/timeout flags to the Mambaforge download.

### 2. `docker/common/install_tf2.sh` — h5py fallback chain + wget fixes

The h5py fallback used `|| { ... } || { ... }` which has shell precedence issues under `set -e`. If the first install method failed, the fallback chain wouldn't execute correctly.

**Fix**: Rewrote as explicit `if/else` with proper fallback from `h5py=2.10.0` to `h5py>=2.10.0,<4.0`. Also quoted `${VAI_CONDA_CHANNEL}` URLs (contain `?` characters that trigger shell globbing) and added step markers for debuggability.

### 3. `docker/common/install_torch.sh` — wget reliability

**Fix**: Added retry/timeout flags (`--retry-connrefused --waitretry=5 --read-timeout=120 --timeout=60 -t 5`) and quoted URLs for all wget calls.

### 4. `docker/common/install_vairuntime.sh` — wget reliability

All 5 wget calls (XRT .deb, XRM .deb, vairuntime tarball, and their recursive fetches) download from `xilinx.com` which 301-redirects to `download.amd.com`. Any transient failure killed the build.

**Fix**: Added retry/timeout flags and quoted URLs on all 5 wget calls.

### 5. `docker/docker_build.sh` — Build output visibility

Default Docker BuildKit output (`--progress=auto`) collapses build output, making it impossible to debug failures.

**Fix**: Added `--progress=plain` to both `docker build` commands (base image and final image).

### 6. `docker/build_tf2_cuda12.sh` + `install_tf2_cuda12.sh` + Dockerfile — Blackwell GPU support

NVIDIA Blackwell GPUs (sm_120) aren't supported by TF 2.12's pre-built kernels. These new files build a CUDA 12.8-based image with TF 2.13.1 that uses PTX JIT compilation for sm_120.

Key details:
- **Base image**: `nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04`
- **TF 2.13.1**: Max version for Python 3.8 (conda env constraint)
- **Keras 2.12**: Downgraded from 2.13 because vai_q_tensorflow2 needs `keras.engine` module
- **nvidia-\*-cu11 pip packages**: Required for TF 2.13 pip wheel GPU detection + LD_LIBRARY_PATH
- **h5py >= 3.0**: Old h5py 2.10.0 incompatible with numpy in TF 2.13

### 7. `docker_run.sh` (repo root) — Simplified for local builds

The original script pulled images from a registry and had lengthy license prompts. Rewritten for locally-built images.

**Fix**: Removed `docker pull` and license prompts. Added image validation, GPU/ROCm auto-detection, and options for X11 forwarding, custom workspace, extra mounts, and custom commands.

## Project Structure

```
Vitis-AI/
  docker_run.sh              # Run containers (use from repo root)
  docker/
    docker_build.sh          # Build entry point
    docker_run.sh            # Run containers (alternative, from docker/)
    common/
      install_base.sh        # System packages (apt)
      install_conda.sh       # Conda/Mamba setup         [MODIFIED]
      install_tf2.sh         # TensorFlow 2 install      [MODIFIED]
      install_torch.sh       # PyTorch install            [MODIFIED]
      install_vairuntime.sh  # Vitis AI runtime install   [MODIFIED]
      install_tf2_cuda12.sh  # TF2 for Blackwell GPUs    [NEW]
    build_tf2_cuda12.sh    # Blackwell GPU build script  [NEW]
    dockerfiles/
      VERSION.txt            # Version string (3.5.0.001)
      ubuntu-vai/
        CondaBase.Dockerfile # Base image Dockerfile
        vitis-ai-cpu.Dockerfile
        vitis-ai-gpu.Dockerfile
        vitis-ai-rocm.Dockerfile
        vitis-ai-gpu-tf2-cuda12.Dockerfile  # Blackwell  [NEW]
    gpu_conda/               # GPU conda environment YMLs
    cpu_conda/               # CPU conda environment YMLs
```

## Troubleshooting

**Build fails with mamba errors**
```
mamba: error: unrecognized arguments: --no-update-deps
```
This means mamba 2.x was installed. The fix in `install_conda.sh` pins it to `<2`. If rebuilding, delete the base image and rebuild without `-s`.

**Build fails during wget/download**
The retry flags handle most transient failures. If downloads still fail, check your internet connection and try again. The `xilinx.com` download URLs redirect to `download.amd.com` — both must be reachable.

**`nvidia-smi` not found inside container**
Ensure the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) is installed and the Docker daemon is restarted.

**Out of disk space during build**
GPU images are ~20-35 GB. Clean up old images with:
```bash
docker system prune -a
```

## Upstream

This fork is based on [Xilinx/Vitis-AI](https://github.com/Xilinx/Vitis-AI) at commit `77cb9e6ad` (v3.5).

## License

[Apache 2.0](LICENSE) — same as upstream. See the LICENSE file for details on binary-only components (xcompiler, WeGO, VAIP, etc.).
