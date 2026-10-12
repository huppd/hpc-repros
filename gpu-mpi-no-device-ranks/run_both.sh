#!/bin/bash
# Build and submit the 2x2 matrix: {uenv stack, /mch-environment/v8} x {NODEV=0,1}.
set -u
UENV_TAG=${1:-icon/26.7:rc2}
V8=/mch-environment/v8
MPICH_DIR=$V8/linux-sles15-zen3/nvhpc-24.5/cray-mpich-8.1.30-plfbchumr6j5tbnfrcszmkjburwtukln
NVHPC_DIR=$V8/linux-sles15-zen3/gcc-12.3.0/nvhpc-24.5-prtvkxggic7vikljoiqdira6isjoxm5n

echo "== building against uenv $UENV_TAG =="
uenv run "$UENV_TAG" --view icon -- mpif90 -O1 -o rma_nodev_uenv rma_nodev.f90 || exit 1

echo "== building against $V8 =="
PATH=$MPICH_DIR/bin:$NVHPC_DIR/Linux_x86_64/24.5/compilers/bin:$PATH \
LD_LIBRARY_PATH=$MPICH_DIR/lib:$NVHPC_DIR/Linux_x86_64/24.5/compilers/lib:${LD_LIBRARY_PATH:-} \
  mpif90 -O1 -o rma_nodev_v8 rma_nodev.f90 || echo "WARNING: v8 build failed - v8 column unobtainable"

for nodev in 0 1; do
  echo "== submitting uenv  NODEV=$nodev =="
  NODEV=$nodev sbatch --export=ALL,NODEV=$nodev --uenv="$UENV_TAG" --view=icon repro.sbatch
  if [ -x ./rma_nodev_v8 ]; then
    echo "== submitting v8    NODEV=$nodev =="
    NODEV=$nodev sbatch --export=ALL,NODEV=$nodev repro_v8.sbatch
  fi
done
echo "PASS = 'ALL STAGES PASSED' in the .out file; a hang shows as the last 'stage N begin' with no matching 'done'."
