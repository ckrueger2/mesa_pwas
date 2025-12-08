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

#accept terms of service
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

#set strict channel priority and configure channels
conda config --set channel_priority strict
conda config --remove-key channels 2>/dev/null || true
conda config --add channels conda-forge

#clone MetaXcan repo if needed
if [ ! -d MetaXcan ]; then
    git clone https://github.com/hakyimlab/MetaXcan
    cd MetaXcan
    if [ -f software/conda_env.yaml ]; then
        conda env create -f software/conda_env.yaml
    else
        #fallback manual environment creation
        conda create -n imlabtools python=3.8 numpy pandas scipy h5py -y
    fi
    cd ..
fi

#create imlabtools manually if not created yet
if ! conda env list | grep -q imlabtools; then
    echo "Creating imlabtools environment manually..."
    conda create -n imlabtools python=3.8 numpy pandas scipy h5py -y
fi

#clone repo and create environment
if [ ! -d MetaXcan ]; then
    git clone https://github.com/hakyimlab/MetaXcan
    cd MetaXcan
    #git checkout 76a11b856f3cbab0b866033d518c201374a5594b
    if [ -f MetaXcan/software/conda_env.yaml ]; then
        conda env create -f software/conda_env.yaml
        cd ..
    else
        #create environment manually as fallback (version numbers may need to be changed with future updates)
        conda create -n imlabtools python=3.8 numpy pandas scipy -y
    fi
    cd ..
fi

#create imlabtools manually if needed (version numbers may need to be changed with future updates)
if ! conda env list | grep -q imlabtools; then
    echo "Failed to create imlabtools environment, creating manually"
    conda create -n imlabtools python=3.8 numpy pandas scipy h5py -y
fi
echo "Setup complete. Activate with: conda activate imlabtools"