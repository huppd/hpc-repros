#!/bin/bash
#SBATCH --job-name=mpi_gtl_repro_v8
#SBATCH --output=repro_v8.out.%j
#SBATCH --gres=gpu:4
#SBATCH --exclusive
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:02:00

MPICH_DIR=/mch-environment/v8/linux-sles15-zen3/nvhpc-24.5/cray-mpich-8.1.30-plfbchumr6j5tbnfrcszmkjburwtukln
GTL_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-gtl-8.1.30-ib3amjzw2zxnfr5jiqtnyuwhxz5fu4ct
PALS_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-pals-1.2.12-ind46nbv254eradnur6gkissunj4oh5u
PMI_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-pmi-6.1.12-urlm6hme3q6sxfmjorasek2egrfm53je
NVHPC_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/nvhpc-24.5-prtvkxggic7vikljoiqdira6isjoxm5n

export LD_LIBRARY_PATH=$MPICH_DIR/lib:$GTL_DIR/lib:$PALS_DIR/lib:$PMI_DIR/lib:$NVHPC_DIR/Linux_x86_64/24.5/compilers/lib:${LD_LIBRARY_PATH:-}

export NVCOMPILER_TERM=trace
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0
export CRAY_CUDA_MPS=1
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_RDMA_ENABLED_CUDA=1

srun ./hello_v8
