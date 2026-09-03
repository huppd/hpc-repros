# cray-mpich GTL / GPUDirect-RDMA `MPI_Init` failure

Bare `MPI_Init`/`MPI_Finalize` (no CUDA, no application code — see
[`hello.f90`](hello.f90)) aborts inside Cray MPICH's GPU Transport Layer
when GPU-aware MPI is enabled:

```
hello_uenv: gtlt_cuda_setup.c:97: gtlt_cuda_init: Assertion `gtlt_cuda_gdr_handle != NULL' failed.
Error: abort
```

Found while debugging an [ICON-NWP](https://icon-model.org) build, but
unrelated to ICON — this reproducer contains none of its code.

## Result

| Environment | `cray-mpich` | `cray-gtl` | Fortran compiler | Result |
|---|---|---|---|---|
| `uenv` stack | 9.1.0 | 9.1.0 | nvhpc 26.1 | **crashes** — [log](crash_uenv_icon-26.7-rc1.log) |
| older module-based stack | 8.1.30 | 8.1.30 | nvhpc 24.5 | **works** — [log](success_mch-environment-v8.log) |

Same node, same SLURM partition, same GPU/MPI env vars
(`MPICH_GPU_SUPPORT_ENABLED=1`, `MPICH_RDMA_ENABLED_CUDA=1`,
`CRAY_CUDA_MPS=1`, `FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0`) — only the
toolchain differs. Points at `cray-mpich@9.1.0`/`cray-gtl@9.1.0` (or its
driver pairing), not a hardware limitation.

## Reproducing

```
./run_both.sh [UENV_TAG]   # defaults to icon/26.7:rc1
```

Builds and submits both variants (`repro.sbatch` for the uenv stack,
`repro_v8.sbatch` for `/mch-environment/v8`, activated via
`LD_LIBRARY_PATH` since it's a plain module tree). Adjust
`--partition=short --gres=gpu:4` in the `.sbatch` files for your own
cluster.

## License

MIT, see [../LICENSE](../LICENSE).
