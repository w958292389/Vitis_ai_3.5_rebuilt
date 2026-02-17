#!/bin/bash
# Install TF2 with CUDA 12.8 support for Blackwell (sm_120) GPUs
# Uses TF 2.13.1 (max version for Python 3.8, has PTX for sm_89 -> JIT to sm_120)
# Force-installs vai_q_tensorflow2 with --no-deps to bypass TF ~=2.12 pin
# (vai_q_tensorflow2 is pure Python and uses only standard tf.keras APIs)
#
# Key: TF 2.13 pip wheel needs nvidia-*-cu11 pip packages for GPU support.
# These provide the CUDA 11.8 runtime libs that TF was compiled against.
# The NVIDIA driver (CUDA 13.0 / 580.x) is forward-compatible and handles
# PTX JIT compilation from sm_89 -> sm_120 at first kernel launch.

set -ex
sudo chmod 777 /scratch

# Download and extract conda channel if needed
if [[ ${VAI_CONDA_CHANNEL} =~ .*"tar.gz" ]]; then
    cd /scratch/
    echo "Downloading conda channel (this may take a while for large files)..."
    wget -O conda-channel.tar.gz --progress=dot:mega \
        --retry-connrefused --waitretry=5 --read-timeout=120 --timeout=60 -t 5 \
        "${VAI_CONDA_CHANNEL}"
    echo "Extracting conda channel..."
    tar -xzf conda-channel.tar.gz
    ls -la /scratch/
    export VAI_CONDA_CHANNEL=file:///scratch/conda-channel
fi

sudo mkdir -p $VAI_ROOT/compiler
conda_channel="${VAI_CONDA_CHANNEL}"

echo "=== GPU TF2 CUDA 12.8 install (TF 2.13.1 + nvidia-cu11 + vai_q_tensorflow2) ==="

. $VAI_ROOT/conda/etc/profile.d/conda.sh
mkdir -p $VAI_ROOT/conda/pkgs

sudo python3 -m pip install --upgrade pip wheel setuptools

# Configure conda channels
conda config --env --remove-key channels || true
conda config --env --append channels ${VAI_CONDA_CHANNEL}
conda config --remove channels defaults || true

echo "=== Creating conda environment from /scratch/${DOCKER_TYPE}_conda/vitis-ai-tensorflow2.yml ==="
mamba env create -f /scratch/${DOCKER_TYPE}_conda/vitis-ai-tensorflow2.yml

conda activate vitis-ai-tensorflow2

echo "=== Installing TensorFlow 2.13.1 (GPU, max version for Python 3.8) ==="
pip install --ignore-installed tensorflow==2.13.1
# Downgrade keras to 2.12 for vai_q_tensorflow2 compat (keras.engine module needed)
pip install --force-reinstall keras==2.12.0

echo "=== Installing NVIDIA CUDA 11 pip packages (required by TF 2.13 pip wheel) ==="
pip install \
    nvidia-cublas-cu11==11.11.3.6 \
    nvidia-cuda-cupti-cu11==11.8.87 \
    nvidia-cuda-nvrtc-cu11==11.8.89 \
    nvidia-cuda-runtime-cu11==11.8.89 \
    nvidia-cudnn-cu11==8.9.6.50 \
    nvidia-cufft-cu11==10.9.0.58 \
    nvidia-curand-cu11==10.3.0.86 \
    nvidia-cusolver-cu11==11.4.1.48 \
    nvidia-cusparse-cu11==11.7.5.86 \
    nvidia-nccl-cu11==2.21.5

# Set up LD_LIBRARY_PATH for nvidia pip packages so TF can find them at runtime
NVIDIA_SITE_PKG="$CONDA_PREFIX/lib/python3.8/site-packages/nvidia"
NVIDIA_LD_PATHS=""
for subdir in $(ls -d ${NVIDIA_SITE_PKG}/*/lib 2>/dev/null); do
    NVIDIA_LD_PATHS="${NVIDIA_LD_PATHS:+${NVIDIA_LD_PATHS}:}${subdir}"
done
echo "NVIDIA pip lib paths: $NVIDIA_LD_PATHS"

# Write activation script so LD_LIBRARY_PATH is set on conda activate
mkdir -p $CONDA_PREFIX/etc/conda/activate.d
cat > $CONDA_PREFIX/etc/conda/activate.d/nvidia_libs.sh << ACTEOF
#!/bin/bash
export LD_LIBRARY_PATH="${NVIDIA_LD_PATHS}:\${LD_LIBRARY_PATH}"
ACTEOF
chmod +x $CONDA_PREFIX/etc/conda/activate.d/nvidia_libs.sh

# Source it now for the rest of this script
export LD_LIBRARY_PATH="${NVIDIA_LD_PATHS}:${LD_LIBRARY_PATH}"

echo "=== Installing h5py (>=3.0 for numpy compat with TF 2.13) ==="
pip uninstall -y h5py || true
pip uninstall -y h5py || true
pip install "h5py>=3.0,<4.0"

echo "=== Force-installing vai_q_tensorflow2 (bypass TF version pin) ==="
pip install --no-deps --force-reinstall vai_q_tensorflow2==3.5.0 || \
    pip install --no-deps --force-reinstall vai-q-tensorflow2==3.5.0 || \
    echo "WARNING: vai_q_tensorflow2 pip install failed, relying on conda version"
# Install vai_q_tensorflow2's non-version-sensitive dependencies
pip install dm-tree~=0.1.1

echo "=== Installing conda packages (pydot, jupyter, etc.) ==="
mamba install --no-update-deps -y pydot pyyaml jupyter ipywidgets \
        dill progressbar2 pytest pandas matplotlib \
        pillow -c ${conda_channel} -c conda-forge -c defaults

echo "=== Installing pip requirements ==="
pip install -r /scratch/pip_requirements.txt || echo "WARNING: pip_requirements.txt install had errors, continuing..."

echo "=== Installing additional pip packages ==="
pip install transformers pycocotools scikit-learn scikit-image tqdm easydict

echo "=== Re-installing TF 2.13.1 + h5py to ensure correct versions ==="
pip install --force-reinstall tensorflow==2.13.1 "h5py>=3.0,<4.0"
# Downgrade keras again (TF reinstall pulls in keras 2.13)
pip install --force-reinstall keras==2.12.0

echo "=== Installing protobuf ==3.20.3 ==="
pip install --force-reinstall protobuf==3.20.3

echo "=== Cleaning up ==="
conda clean -y --force-pkgs-dirs
sudo rm -fr ~/.cache
sudo rm -fr /scratch/*
conda config --env --remove-key channels || true

conda activate vitis-ai-tensorflow2
sudo mkdir -p $VAI_ROOT/compiler
sudo cp -r $CONDA_PREFIX/lib/python3.8/site-packages/vaic/arch $VAI_ROOT/compiler/arch
echo "=== GPU TF2 CUDA 12.8 install completed successfully ==="
