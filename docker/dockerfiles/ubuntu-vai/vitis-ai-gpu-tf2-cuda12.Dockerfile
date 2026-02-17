# Custom Dockerfile for GPU-only TF2 with CUDA 12.8 + TF 2.13.1
# Based on vitis-ai-cpu.Dockerfile but skips FPGA runtime (XRT/XRM/vairuntime)
# which has Ubuntu 18.04 dependencies incompatible with the CUDA 12.x base.
# Uses install_tf2_cuda12.sh which installs TF 2.13.1 for Blackwell (sm_120) support.

ARG VAI_BASE
FROM $VAI_BASE

ARG TARGET_FRAMEWORK
ENV TARGET_FRAMEWORK=$TARGET_FRAMEWORK
ARG VAI_CONDA_CHANNEL="file:///scratch/conda-channel"
ENV VAI_CONDA_CHANNEL=$VAI_CONDA_CHANNEL
ARG VERSION
ENV VERSION=$VERSION
ARG DOCKER_TYPE='gpu'
ENV DOCKER_TYPE=$DOCKER_TYPE

WORKDIR /workspace
ADD ./common/ .
ADD ./conda /scratch
ADD conda/banner.sh /etc/
ADD conda/${DOCKER_TYPE}_conda/bashrc /etc/bash.bashrc
# Override install_tf2.sh with CUDA 12.8 / TF 2.13.1 version
COPY ./common/install_tf2_cuda12.sh ./install_tf2.sh
RUN if [[ -n "${TARGET_FRAMEWORK}" ]]; then bash ./install_${TARGET_FRAMEWORK}.sh; fi
USER root
RUN mkdir -p ${VAI_ROOT}/conda/pkgs && chmod 777 ${VAI_ROOT}/conda/pkgs && rm -fr ./*
