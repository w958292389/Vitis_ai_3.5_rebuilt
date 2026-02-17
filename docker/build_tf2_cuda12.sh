#!/usr/bin/env bash
# Build Vitis AI TF2 GPU image with CUDA 12.8 base + TF 2.15
# For Blackwell (sm_120) GPU support via PTX JIT compilation
# (leaves the original docker_build.sh untouched)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VAI_BASE="nvidia/cuda:12.8.1-cudnn-devel-ubuntu20.04"
BASE_TAG="xilinx/vitis-ai-gpu-tf2-base:cuda12.8"
FINAL_TAG="xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-cuda12.8"
VAI_CONDA_CHANNEL="https://www.xilinx.com/bin/public/openDownload?filename=conda-channel-3.5.0.tar.gz"
VERSION="3.5.0.001-cuda12.8"

echo "=== Step 1/2: Building base image ($BASE_TAG) ==="
echo "    Base: $VAI_BASE"
docker build --progress=plain --network=host \
  --build-arg DOCKER_TYPE=gpu \
  --build-arg VAI_BASE="$VAI_BASE" \
  -t "$BASE_TAG" \
  -f dockerfiles/ubuntu-vai/CondaBase.Dockerfile .

echo ""
echo "=== Step 2/2: Building final image ($FINAL_TAG) ==="
docker build --progress=plain --network=host \
  --build-arg TARGET_FRAMEWORK=tf2 \
  --build-arg DOCKER_TYPE=gpu \
  --build-arg VAI_BASE="$BASE_TAG" \
  --build-arg VAI_CONDA_CHANNEL="$VAI_CONDA_CHANNEL" \
  --build-arg VERSION="$VERSION" \
  -f dockerfiles/ubuntu-vai/vitis-ai-gpu-tf2-cuda12.Dockerfile \
  -t "$FINAL_TAG" ./

echo ""
echo "=== Done ==="
echo "Run with:"
echo "  docker run --gpus all -it $FINAL_TAG bash"
echo ""
echo "Verify with:"
echo "  nvidia-smi"
echo "  python -c \"import tensorflow as tf; print(tf.__version__); print(tf.config.list_physical_devices('GPU'))\""
echo "  python -c \"from tensorflow_model_optimization.quantization.keras import vitis_quantize; print('quantizer OK')\""
