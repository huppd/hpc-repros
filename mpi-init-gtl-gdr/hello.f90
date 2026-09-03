PROGRAM hello
  USE mpi
  IMPLICIT NONE
  INTEGER :: ierr, rank, size
  CALL MPI_Init(ierr)
  CALL MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  CALL MPI_Comm_size(MPI_COMM_WORLD, size, ierr)
  PRINT *, 'Hello from rank', rank, 'of', size
  CALL MPI_Finalize(ierr)
END PROGRAM hello
