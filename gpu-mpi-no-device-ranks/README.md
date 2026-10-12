# cray-mpich hang in `MPI_Init` when some ranks have no visible CUDA device

With GPU-aware MPI enabled (`MPICH_GPU_SUPPORT_ENABLED=1`), a job in which
*some* ranks have an empty `CUDA_VISIBLE_DEVICES` hangs inside
`MPI_Init_thread` under `cray-mpich@9.1.0`. The GPU-less ranks report

```
GTL_DEBUG: [8] cudaGetDeviceCount: no CUDA-capable device is detected
GTL_DEBUG: [9] cudaGetDeviceCount: no CUDA-capable device is detected
```

and `MPI_Init_thread` never returns on any rank — the job runs to its wall
clock limit. The same binary, same node, same environment, with every rank
given a GPU, completes in seconds.

`cray-mpich@8.1.30` handles the GPU-less ranks without complaint, so this is a
**regression between 8.1.30 and 9.1.0**, not a standing limitation.

This matters for applications that dedicate some ranks to I/O or other
host-only service work: those ranks have no reason to hold a GPU, and on a node
with fewer GPUs than ranks the natural layout is to give them none.

Found while working on [ICON-NWP](https://icon-model.org), but unrelated to it
— this reproducer contains none of its code. (ICON currently works around the
problem by handing every rank a GPU via modulo wrap-around, so service ranks
share a device with compute ranks.)

## Result

| Environment | `cray-mpich` | all ranks have a GPU | service ranks `CUDA_VISIBLE_DEVICES=""` |
|---|---|---|---|
| `uenv` stack `icon/26.7:rc2` | 9.1.0.794 | **passes** — [log](success_uenv_icon-26.7-rc2_alldev.log) | **hangs in `MPI_Init`** — [log](hang_uenv_icon-26.7-rc2_nodev.log) |
| older module-based stack | 8.1.30.8 | **passes** — [log](success_mch-environment-v8_alldev.log) | **passes** — [log](success_mch-environment-v8_nodev.log) |

Same node pair, same SLURM partition, same GPU/MPI env vars
(`MPICH_GPU_SUPPORT_ENABLED=1`, `MPICH_RDMA_ENABLED_CUDA=1`, `CRAY_CUDA_MPS=1`,
`FI_CXI_SAFE_DEVMEM_COPY_THRESHOLD=0`) — only the toolchain differs.

The failure is at stage 1 of 4, i.e. in `MPI_Init_thread` itself, before any
communicator, window or one-sided call exists. The later RMA stages are
included only to show they are *not* implicated.

## What the reproducer does

[`rma_nodev.f90`](rma_nodev.f90), 14 ranks over 2 nodes (8 "work" + 6
"service"), four stages, each announced before and after so a hang is
localised:

1. `MPI_Init_thread`
2. `MPI_Barrier` + `MPI_Allreduce` over `MPI_COMM_WORLD`
3. `MPI_Alloc_mem` + `MPI_Win_create` over the full communicator
4. workers `MPI_Win_lock(MPI_LOCK_EXCLUSIVE, self, MPI_MODE_NOCHECK)` / `unlock`;
   service ranks `MPI_Win_lock_all` + `MPI_Rget` from every worker +
   `MPI_Waitall` + `MPI_Win_unlock_all`

Stages 3-4 mirror the access pattern of ICON's asynchronous output. There are no
CUDA calls anywhere in the program.

[`wrapper.sh`](wrapper.sh) does the per-rank GPU assignment and carries the
switch: `NODEV=0` gives every rank a GPU by modulo wrap-around, `NODEV=1` gives
a GPU only to local ids `< 4` and leaves `CUDA_VISIBLE_DEVICES` empty for the
rest.

## Reproducing

```
./run_both.sh [UENV_TAG]   # defaults to icon/26.7:rc2
```

Builds both binaries and submits all four cells of the matrix
(`repro.sbatch` for the uenv stack, `repro_v8.sbatch` for
`/mch-environment/v8`, activated via `LD_LIBRARY_PATH` since it is a plain
module tree). Adjust `--partition`, `--gres=gpu:4` and the node count for your
own cluster.

A pass prints `ALL STAGES PASSED`. A hang shows up as the last
`stage N begin` with no matching `stage N done`, and the job hitting its
`--time` limit.

## License

MIT, see [../LICENSE](../LICENSE).
