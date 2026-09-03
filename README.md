# hpc-repros

Minimal, standalone reproducers for HPC toolchain bugs (compilers, MPI,
GPU/driver stack, ...), stripped down to the smallest case that still shows
the problem. Each subdirectory is one self-contained case.

## Cases

| Case | Symptom | Root cause area |
|---|---|---|
| [`mpi-init-gtl-gdr/`](mpi-init-gtl-gdr/) | `MPI_Init` aborts with `gtlt_cuda_init: Assertion 'gtlt_cuda_gdr_handle != NULL' failed` when GPU-aware MPI is enabled | Cray MPICH GTL / GPUDirect-RDMA |

## License

MIT, see [LICENSE](LICENSE).
