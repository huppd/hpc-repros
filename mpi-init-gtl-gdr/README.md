# cray-mpich GTL / GPUDirect-RDMA `MPI_Init` failure

Minimal reproducer for a Cray MPICH GPU Transport Layer (GTL) initialization
failure observed on a Balfrin-class cluster (CSCS) when GPU-aware MPI is
enabled:

```
hello_uenv: gtlt_cuda_setup.c:97: gtlt_cuda_init: Assertion `gtlt_cuda_gdr_handle != NULL' failed.
Error: abort
```

This crash happens **inside `MPI_Init` itself**, before any application code
runs — no CUDA calls, no device buffers, nothing but `MPI_Init` +
`MPI_Comm_rank`/`MPI_Comm_size` + `MPI_Finalize` (see [`hello.f90`](hello.f90),
~10 lines of Fortran). It was originally found while debugging an
[ICON-NWP](https://icon-model.org) build, but is completely unrelated to ICON:
this reproducer contains no ICON code at all.

## Result

| Environment | `cray-mpich` | `cray-gtl` | Fortran compiler | `MPI_Init` with `MPICH_GPU_SUPPORT_ENABLED=1` |
|---|---|---|---|---|
| `uenv` stack (module system A) | 9.1.0 | 9.1.0 | nvhpc 26.1 | **crashes** — see [`crash_uenv_icon-26.7-rc1.log`](crash_uenv_icon-26.7-rc1.log) |
| older module-based stack (module system B) | 8.1.30 | 8.1.30 | nvhpc 24.5 | **works** — see [`success_mch-environment-v8.log`](success_mch-environment-v8.log) |

Both runs used the same node, the same SLURM partition, and the same GPU/MPI
tuning environment variables (`MPICH_GPU_SUPPORT_ENABLED=1`,
`MPICH_RDMA_ENABLED_CUDA=1`, `CRAY_CUDA_MPS=1`, `FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0`).
Only the toolchain differs. Since GPUDirect RDMA works fine on this exact
hardware with the older `cray-mpich`/`cray-gtl` build, this points at the
newer `cray-mpich@9.1.0`/`cray-gtl@9.1.0` build (or its pairing with this
node's driver) rather than a hardware/node limitation.

## Files

- `hello.f90` — the reproducer itself.
- `Makefile` — builds `hello.f90` against whatever `mpif90` is currently
  active (`make FC=mpif90`).
- `repro.sbatch` / `repro_v8.sbatch` — SLURM job scripts for the two
  environments.
- `run_both.sh` — builds and submits both variants in one go (see below).
- `crash_uenv_icon-26.7-rc1.log` / `success_mch-environment-v8.log` — captured
  output from the runs described above.

## Reproducing

```
./run_both.sh [UENV_TAG]
```

`UENV_TAG` defaults to `icon/26.7:rc1`. The script:

1. Builds and submits the uenv variant (`repro.sbatch`) via
   `sbatch --uenv=... --view=icon --wait` — expected to crash.
2. Builds and submits the `/mch-environment/v8` variant (`repro_v8.sbatch`),
   activating that stack's `cray-mpich`/`cray-gtl`/`cray-pmi`/`cray-pals` via
   `LD_LIBRARY_PATH` (it's a plain module tree, not a uenv) — expected to
   succeed.

Both use `--partition=short --gres=gpu:4 --exclusive --nodes=1
--ntasks-per-node=4`; adjust to match your own cluster's GPU partition if
reusing this outside the original environment.

To build/run just one side manually:

```
uenv run icon/26.7:rc1 --view icon -- mpif90 -o hello_uenv hello.f90
sbatch --uenv=icon/26.7:rc1 --view=icon --wait repro.sbatch
```

## License

MIT, see [../LICENSE](../LICENSE).
