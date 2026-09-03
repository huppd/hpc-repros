# hpc-repros

A collection of minimal, standalone reproducers for HPC toolchain bugs
(compilers, MPI, GPU/driver stack, ...) found while working on real
applications, stripped down to the smallest case that still shows the
problem.

Each subdirectory is one self-contained case: its own README, its own build
and run instructions, no dependency on the application it was originally
found in.

## Cases

| Case | Symptom | Root cause area |
|---|---|---|
| [`mpi-init-gtl-gdr/`](mpi-init-gtl-gdr/) | `MPI_Init` aborts with `gtlt_cuda_init: Assertion 'gtlt_cuda_gdr_handle != NULL' failed` when GPU-aware MPI is enabled | Cray MPICH GTL / GPUDirect-RDMA |

## License

MIT, see [LICENSE](LICENSE) (applies to all cases unless a case says
otherwise).
