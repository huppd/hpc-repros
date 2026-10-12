! Minimal reproducer: GPU-aware cray-mpich with some ranks having no visible
! CUDA device, exercising the one-sided (RMA) call pattern used by ICON's
! asynchronous output.
!
! Four stages, each announced before and after, so a hang is localised:
!   1 MPI_Init_thread
!   2 collective over MPI_COMM_WORLD
!   3 MPI_Win_create over the work+io communicator (GPU-less ranks take part)
!   4 MPI_Win_lock_all + MPI_Rget + MPI_Waitall + MPI_Win_unlock_all
!
! No CUDA calls, no application code.
program rma_nodev
  use mpi
  use iso_c_binding, only: c_ptr, c_f_pointer
  use iso_fortran_env, only: output_unit, real64
  implicit none

  integer, parameter :: dp = real64
  integer :: ierr, provided, rank, nranks, nwork, np, nreq, i
  integer :: win, dsize
  integer(kind=MPI_ADDRESS_KIND) :: nbytes, target_disp
  integer, allocatable :: reqs(:)
  real(dp), pointer :: winbuf(:) => null()
  real(dp), allocatable :: getbuf(:)
  type(c_ptr) :: cptr
  integer, parameter :: NELEM = 1024
  character(len=64) :: cvd, env_nwork
  character(len=MPI_MAX_PROCESSOR_NAME) :: host
  integer :: hostlen, stat

  call say(-1, 'stage 1 begin: MPI_Init_thread')
  call MPI_Init_thread(MPI_THREAD_SERIALIZED, provided, ierr)
  call check(ierr, 'MPI_Init_thread')
  call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierr)
  call MPI_Comm_size(MPI_COMM_WORLD, nranks, ierr)
  call MPI_Get_processor_name(host, hostlen, ierr)

  call get_environment_variable('CUDA_VISIBLE_DEVICES', cvd, status=stat)
  if (stat /= 0) cvd = '<unset>'
  if (len_trim(cvd) == 0) cvd = '<empty>'
  write(output_unit,'(a,i4,a,i4,a,a,a,a)') 'rank ', rank, '/', nranks, &
       ' host ' // trim(host(1:hostlen)) // ' CUDA_VISIBLE_DEVICES=' // trim(cvd)
  flush(output_unit)
  call say(rank, 'stage 1 done: MPI_Init_thread')

  ! how many leading ranks are "work" PEs; the rest are the GPU-less service PEs
  call get_environment_variable('NWORK', env_nwork, status=stat)
  if (stat == 0 .and. len_trim(env_nwork) > 0) then
     read(env_nwork,*) nwork
  else
     nwork = max(1, nranks - 6)
  end if

  call say(rank, 'stage 2 begin: Barrier + Allreduce')
  call MPI_Barrier(MPI_COMM_WORLD, ierr); call check(ierr, 'MPI_Barrier')
  call MPI_Allreduce(MPI_IN_PLACE, nreq, 1, MPI_INTEGER, MPI_SUM, MPI_COMM_WORLD, ierr)
  call check(ierr, 'MPI_Allreduce')
  call say(rank, 'stage 2 done')

  ! ---- stage 3: window over the whole communicator (ICON: p_comm_work_io) ----
  call say(rank, 'stage 3 begin: MPI_Alloc_mem + MPI_Win_create')
  call MPI_Type_size(MPI_DOUBLE_PRECISION, dsize, ierr)
  nbytes = int(NELEM, MPI_ADDRESS_KIND) * int(dsize, MPI_ADDRESS_KIND)
  call MPI_Alloc_mem(nbytes, MPI_INFO_NULL, cptr, ierr); call check(ierr, 'MPI_Alloc_mem')
  call c_f_pointer(cptr, winbuf, (/ NELEM /))
  winbuf(:) = real(rank, dp)
  call MPI_Win_create(winbuf, nbytes, dsize, MPI_INFO_NULL, MPI_COMM_WORLD, win, ierr)
  call check(ierr, 'MPI_Win_create')
  call say(rank, 'stage 3 done')

  ! ---- stage 4: the ICON async-output access pattern ----
  call say(rank, 'stage 4 begin: lock/Rget/unlock')
  if (rank < nwork) then
     ! worker: lock own window exclusively around a local write, as ICON does
     call MPI_Win_lock(MPI_LOCK_EXCLUSIVE, rank, MPI_MODE_NOCHECK, win, ierr)
     call check(ierr, 'MPI_Win_lock(self)')
     winbuf(:) = real(100 + rank, dp)
     call MPI_Win_unlock(rank, win, ierr); call check(ierr, 'MPI_Win_unlock(self)')
  else
     ! service PE: read every worker's window
     allocate(getbuf(NELEM * nwork), reqs(nwork))
     call MPI_Win_lock_all(MPI_MODE_NOCHECK, win, ierr); call check(ierr, 'MPI_Win_lock_all')
     target_disp = 0
     do np = 0, nwork - 1
        call MPI_Rget(getbuf(np*NELEM + 1), NELEM, MPI_DOUBLE_PRECISION, np, &
                      target_disp, NELEM, MPI_DOUBLE_PRECISION, win, reqs(np+1), ierr)
        call check(ierr, 'MPI_Rget')
     end do
     call MPI_Waitall(nwork, reqs, MPI_STATUSES_IGNORE, ierr); call check(ierr, 'MPI_Waitall')
     call MPI_Win_unlock_all(win, ierr); call check(ierr, 'MPI_Win_unlock_all')
     deallocate(getbuf, reqs)
  end if
  call MPI_Barrier(MPI_COMM_WORLD, ierr)
  call say(rank, 'stage 4 done')

  call MPI_Win_free(win, ierr)
  call MPI_Free_mem(winbuf, ierr)
  call MPI_Barrier(MPI_COMM_WORLD, ierr)
  if (rank == 0) then
     write(output_unit,'(a,i0,a,i0,a)') 'ALL STAGES PASSED (', nwork, ' work + ', &
          nranks - nwork, ' service ranks)'
     flush(output_unit)
  end if
  call MPI_Finalize(ierr)

contains
  subroutine say(r, msg)
    integer, intent(in) :: r
    character(len=*), intent(in) :: msg
    if (r < 0) then
       write(output_unit,'(a)') '[pre-init] ' // msg
    else
       write(output_unit,'(a,i4,a)') '[rank ', r, '] ' // msg
    end if
    flush(output_unit)
  end subroutine say

  subroutine check(ie, what)
    integer, intent(in) :: ie
    character(len=*), intent(in) :: what
    if (ie /= MPI_SUCCESS) then
       write(output_unit,'(a,i0)') 'ERROR in ' // what // ', code ', ie
       flush(output_unit)
       call MPI_Abort(MPI_COMM_WORLD, 1, ierr)
    end if
  end subroutine check
end program rma_nodev
