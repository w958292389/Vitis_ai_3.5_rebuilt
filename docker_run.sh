#!/usr/bin/env bash
# Copyright 2022 Xilinx Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Modified for locally-built GPU Docker images.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERE="$(pwd -P)"

# Defaults
DETACHED="-it"
WORKSPACE="$SCRIPT_DIR"
RUN_MODE=""
EXTRA_ARGS=""

function usage() {
    cat <<EOF
Usage: $0 [OPTIONS] IMAGE_NAME:TAG [COMMAND]

Run a Vitis AI Docker container from a locally-built image.

Arguments:
  IMAGE_NAME:TAG        Docker image to run (required)
  COMMAND               Command to run inside container (default: bash)

Options:
  -d                    Run container in detached mode
  -X                    Enable X11 forwarding (GUI support)
  -w DIR                Mount DIR as /workspace (default: Vitis-AI repo root)
  -e VAR=VAL            Pass extra environment variable to container
  -v SRC:DST            Add extra volume mount
  -h, --help            Show this help message

Examples:
  ./docker_run.sh xilinx/vitis-ai-pytorch-gpu:3.5.0.001-77cb9e6ad
  ./docker_run.sh -X xilinx/vitis-ai-tensorflow2-gpu:3.5.0.001-77cb9e6ad
  ./docker_run.sh -w /data/project xilinx/vitis-ai-pytorch-gpu:3.5.0.001-77cb9e6ad
  ./docker_run.sh xilinx/vitis-ai-pytorch-gpu:3.5.0.001-77cb9e6ad python my_script.py

Available images:
EOF
    docker images --format '  {{.Repository}}:{{.Tag}}' 2>/dev/null | grep vitis-ai || echo "  (none found)"
    exit "${1:-0}"
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d)
            DETACHED="-d"
            shift
            ;;
        -X)
            RUN_MODE="gui"
            shift
            ;;
        -w)
            WORKSPACE="$2"
            shift 2
            ;;
        -e)
            EXTRA_ARGS+=" -e $2"
            shift 2
            ;;
        -v)
            EXTRA_ARGS+=" -v $2"
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        -*)
            echo "Error: Unknown option '$1'"
            usage 1
            ;;
        *)
            IMAGE_NAME="$1"
            shift
            break
            ;;
    esac
done

# Remaining args become the container command
DEFAULT_COMMAND="${*:-bash}"

if [ -z "$IMAGE_NAME" ]; then
    echo "Error: No image specified."
    echo ""
    usage 1
fi

# Verify image exists locally
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "Error: Image '$IMAGE_NAME' not found locally."
    echo ""
    echo "Available Vitis AI images:"
    docker images --format '  {{.Repository}}:{{.Tag}}' 2>/dev/null | grep vitis-ai || echo "  (none)"
    echo ""
    echo "Build with: cd docker && ./docker_build.sh -t gpu -f pytorch"
    exit 1
fi

# Current user info
user=$(whoami)
uid=$(id -u)
gid=$(id -g)

# Detect Xilinx FPGA/DPU devices
docker_devices=""
for dev in $(find /dev -name 'xclmgmt*' 2>/dev/null); do
    docker_devices+="--device=$dev "
done
for dev in $(find /dev/dri -name 'renderD*' 2>/dev/null); do
    docker_devices+="--device=$dev "
done
# ROCm KFD device
for dev in $(find /dev -name 'kfd*' 2>/dev/null); do
    docker_devices+="--device=$dev "
done

# GPU support
gpu_args=""
if [[ "$IMAGE_NAME" == *"gpu"* ]]; then
    if command -v nvidia-smi &>/dev/null; then
        gpu_args="--gpus all"
        echo "GPU mode: detected NVIDIA GPU(s)"
        nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sed 's/^/  /'
    else
        echo "Warning: Image appears to be GPU but nvidia-smi not found."
    fi
fi

# ROCm support
rocm_args=""
if [[ "$IMAGE_NAME" == *"rocm"* ]]; then
    rocm_args="--group-add=render --group-add video --ipc=host --cap-add=SYS_PTRACE --security-opt seccomp=unconfined"
    echo "ROCm mode enabled"
fi

# X11 / GUI forwarding
gui_args=""
post_cmd=""
if [ "$RUN_MODE" = "gui" ]; then
    xauth_file="/tmp/.Xauthority-${user}"
    cp -f "$HOME/.Xauthority" "$xauth_file" 2>/dev/null || true
    chmod a+rw "$xauth_file" 2>/dev/null || true
    gui_args="-e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix -v ${xauth_file}:${xauth_file}"
    post_cmd="rm -f ${xauth_file}"
    echo "GUI mode: X11 forwarding enabled"
fi

# Workspace
if [ ! -d "$WORKSPACE" ]; then
    echo "Error: Workspace directory '$WORKSPACE' does not exist."
    exit 1
fi

echo "Workspace: $WORKSPACE -> /workspace"
echo "Image:     $IMAGE_NAME"
echo "Command:   $DEFAULT_COMMAND"
echo ""

docker run \
    ${DETACHED} \
    --rm \
    --network=host \
    ${gpu_args} \
    ${rocm_args} \
    ${docker_devices} \
    ${gui_args} \
    -v /dev/shm:/dev/shm \
    -v /opt/xilinx/dsa:/opt/xilinx/dsa \
    -v /opt/xilinx/overlaybins:/opt/xilinx/overlaybins \
    -v "${SCRIPT_DIR}":/vitis_ai_home \
    -v "${WORKSPACE}":/workspace \
    -w /workspace \
    -e USER="$user" \
    -e UID="$uid" \
    -e GID="$gid" \
    ${EXTRA_ARGS} \
    "$IMAGE_NAME" \
    $DEFAULT_COMMAND

run_status=$?

if [ -n "$post_cmd" ]; then
    eval "$post_cmd"
fi

exit $run_status
