#!/bin/bash

#install and initialize miniconda if not present
if [ ! -d ~/miniconda3 ]; then
    mkdir -p ~/miniconda3
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
    bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
    rm ~/miniconda3/miniconda.sh
    eval "$(~/miniconda3/bin/conda shell.bash hook)"
    conda init bash
fi

#use the user-level conda
export PATH=~/miniconda3/bin:$PATH
eval "$(conda shell.bash hook)"

#set strict channel priority
conda config --set channel_priority strict

#clone MetaXcan repo if needed
if [ ! -d MetaXcan ]; then
    git clone https://github.com/hakyimlab/MetaXcan
    cd MetaXcan
    if [ -f software/conda_env.yaml ]; then
        conda env create -f software/conda_env.yaml
        cd ..
    else
        # fallback manual environment creation
        conda create -n imlabtools python=3.8 numpy pandas scipy -y
    fi
    cd ..
fi

#create imlabtools manually if not created yet
if ! conda env list | grep -q imlabtools; then
    echo "Creating imlabtools environment manually..."
    conda create -n imlabtools python=3.8 numpy pandas scipy h5py -y
fi

echo "Setup complete. Activate with: conda activate imlabtools"
