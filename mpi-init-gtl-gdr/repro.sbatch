#!/bin/bash
#SBATCH --job-name=mpi_gtl_repro
#SBATCH --output=repro.out.%j
#SBATCH --gres=gpu:4
#SBATCH --exclusive
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=4
#SBATCH --time=00:02:00

export NVCOMPILER_TERM=trace
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0
export CRAY_CUDA_MPS=1
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_RDMA_ENABLED_CUDA=1

srun ./hello_uenv
