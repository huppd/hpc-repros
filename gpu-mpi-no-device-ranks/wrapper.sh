#!/bin/bash
# Mirrors ICON's run/run_wrapper/alps_mch_gpu.sh.
#   NODEV=0 (default) : every rank gets a GPU, modulo wrap-around  -> current ICON
#   NODEV=1           : only local ids < 4 get a GPU; the rest get none -> the
#                       configuration removed by ICON commit 7f051744f8
GPUS=(3 2 1 0)
NUMA=(0 1 2 3)
LR=$SLURM_LOCALID
NUMA_NODE=${NUMA[$LR % ${#NUMA[@]}]}

if [[ "${NODEV:-0}" == "1" && $LR -ge ${#GPUS[@]} ]]; then
    export CUDA_VISIBLE_DEVICES=""
else
    export CUDA_VISIBLE_DEVICES=${GPUS[$LR % ${#GPUS[@]}]}
fi

exec numactl --cpunodebind=$NUMA_NODE --membind=$NUMA_NODE "$@"
