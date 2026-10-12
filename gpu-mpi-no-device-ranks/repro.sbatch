#!/bin/bash
#SBATCH --job-name=rma_nodev
#SBATCH --output=repro.out.%j
#SBATCH --gres=gpu:4
#SBATCH --exclusive
#SBATCH --partition=short
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=7
#SBATCH --time=00:05:00

export NVCOMPILER_TERM=trace
export FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0
export CRAY_CUDA_MPS=1
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export NWORK=8

echo "### NODEV=${NODEV:-0} (1 = service ranks get no GPU)"
srun -n 14 --distribution=plane=4 --threads-per-core=1 ./wrapper.sh ./rma_nodev_uenv
