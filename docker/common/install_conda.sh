#!/bin/bash                                                                                                                                                                     
  
set -ex
if [[ ${DOCKER_TYPE} =~ .*'rocm'*  && ${TARGET_FRAMEWORK} =~ .*"pytorch"  ]]; then
   ln -s /opt/conda $VAI_ROOT/conda;

else

    export HOME=~vitis-ai-user
    if [[ -d "/root/.local" ]]; then
       sudo  chmod -R 777 /root/.local
    fi
    sudo chmod 777 /root /root/.local  /root/.local/bin || true 

cd /tmp \
    && wget --progress=dot:mega --retry-connrefused --waitretry=5 --read-timeout=60 --timeout=30 -t 5 \
       https://github.com/conda-forge/miniforge/releases/download/4.10.3-5/Mambaforge-4.10.3-5-Linux-x86_64.sh -O miniconda.sh \
    && /bin/bash ./miniconda.sh -b -p $VAI_ROOT/conda \
    && . $VAI_ROOT/conda/etc/profile.d/conda.sh \
    && echo "Updating mamba (pinned <2) and conda for repodata compatibility..." \
    && mamba update -n base -y "mamba>=1.5,<2" "conda>=23,<25" \
    && rm -fr /tmp/miniconda.sh \
    &&  /$VAI_ROOT/conda/bin/conda clean -y --force-pkgs-dirs
fi

echo ". $VAI_ROOT/conda/etc/profile.d/conda.sh" >> ~vitis-ai-user/.bashrc
sudo ln -s $VAI_ROOT/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh
