#!/bin/bash
# Compiles and submits both variants of the reproducer:
#   1. the current uenv (icon/26.7:rc1, cray-mpich@9.1.0 / cray-gtl@9.1.0) -- expected to crash
#   2. the old /mch-environment/v8 stack (cray-mpich@8.1.30 / cray-gtl@8.1.30) -- expected to work
#
# Usage: ./run_both.sh [UENV_TAG]
#   UENV_TAG defaults to icon/26.7:rc1
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
cd "$SCRIPT_DIR"

UENV_TAG=${1:-icon/26.7:rc1}

echo "=============================================================="
echo "1/2: uenv variant ($UENV_TAG)"
echo "=============================================================="
uenv run "$UENV_TAG" --view icon -- mpif90 -o hello_uenv hello.f90
# This job is expected to fail (that's the bug being reproduced), so don't
# let `set -e` abort the script over its non-zero exit status.
sbatch --uenv="$UENV_TAG" --view=icon --wait \
  --job-name=mpi_gtl_repro_uenv \
  --output=crash_uenv_icon-26.7-rc1.out.%j \
  repro.sbatch || true
echo

echo "=============================================================="
echo "2/2: /mch-environment/v8 variant"
echo "=============================================================="
MPICH_DIR=/mch-environment/v8/linux-sles15-zen3/nvhpc-24.5/cray-mpich-8.1.30-plfbchumr6j5tbnfrcszmkjburwtukln
GTL_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-gtl-8.1.30-ib3amjzw2zxnfr5jiqtnyuwhxz5fu4ct
PALS_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-pals-1.2.12-ind46nbv254eradnur6gkissunj4oh5u
PMI_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/cray-pmi-6.1.12-urlm6hme3q6sxfmjorasek2egrfm53je
NVHPC_DIR=/mch-environment/v8/linux-sles15-zen3/gcc-12.3.0/nvhpc-24.5-prtvkxggic7vikljoiqdira6isjoxm5n

export LD_LIBRARY_PATH=$MPICH_DIR/lib:$GTL_DIR/lib:$PALS_DIR/lib:$PMI_DIR/lib:$NVHPC_DIR/Linux_x86_64/24.5/compilers/lib:${LD_LIBRARY_PATH:-}
"$MPICH_DIR/bin/mpif90" -o hello_v8 hello.f90
sbatch --wait \
  --job-name=mpi_gtl_repro_v8 \
  --output=success_mch-environment-v8.out.%j \
  repro_v8.sbatch
echo

echo "=============================================================="
echo "Done. Compare crash_uenv_icon-26.7-rc1.out.* (expected: crash)"
echo "against success_mch-environment-v8.out.* (expected: 4x hello)."
echo "=============================================================="
