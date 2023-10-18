program ice

    use datetime, ONLY: datetime_init, datetime_str, datetime_type, delta_init
    use datetime, ONLY: datetime_delta_type, OPERATOR(+), OPERATOR(<), OPERATOR(==), OPERATOR(-)
    use datetime, ONLY: str2dt, datetime_str_6, now, delta_str
    use omp_lib
    use mpi

    implicit none

    include "parameter.h"
    include "CB_const.h"
    include "CB_mpi.h"

    integer :: tstep
    integer :: expno, readnamelist, restart, expno_r, nt_r
    integer :: proc_num, thread_num, num_threads
    type(datetime_type) :: tic, tac
    character(len=2) :: expno_str, expno_str_r
    character(10) :: n_str

    ! execute godar only on master rank
    call mpi_init(ierr)
    call mpi_comm_rank(mpi_comm_world, rank, ierr)
    call mpi_comm_size(mpi_comm_world, n_ranks, ierr)

    !---------------------------------------------------------------
    !       Read run information
    !---------------------------------------------------------------

    if ( rank .eq. master ) then

        tic = now()

        print '(a)', &
        '',&
        '|========================================================|',&
        '|                                                        |',&
        '|   Welcome in GODAR (Granular flOes for Discrete        |',&
        '|   Arctic Representation). Please use the input file    |',&
        '|   as arguments to this program. If not, please provide |',&
        '|   the following:                                       |',&
        '|                                                        |',&
        '|========================================================|',&
        ''  

        ! read if inputing namelist or not
        print *, 'Read namelist? (0/1)'
        read  *, readnamelist
        print *, readnamelist

        ! read if restarting or not
        print *, 'Restart experiment from previous one? (0/1)'
        read  *, restart
        print *, restart

        if (restart .eq. 1) then
            ! read restarting experience number
            read *, expno_r
            print *, "Restart from experiment number: (XX)"
            print *, expno_r
            write(expno_str_r,'(i2.2)') expno_r
            read *, nt_r

            print *, "Last iteration of restart experiment is:"
            print *, nt_r
        endif

        ! read experience number
        print *, 'This experiment number? (XX)'
        read  *, expno 
        print *, expno 
        write(expno_str,'(i2.2)') expno
        write(n_str,'(i0)') n

        call get_default
        ! overwrite default based on namelist
        if (readnamelist .eq. 1) then
            call read_namelist
        endif

        call ini_get (restart, expno_str_r, nt_r)

        call clear_posts (expno_str)

        !number of processor/threads
        print '(a)', &
        '',&
        '|--------------------------------------------------------|',&
        '|                                                        |',&
        '|   Checking the number of threads to use.               |',&
        '|                                                        |',&
        '|--------------------------------------------------------|',&
        '' 

        proc_num = omp_get_num_procs ( )
        thread_num = omp_get_max_threads ( )

        print *, 'Number of processors available: ', proc_num
        print *, 'Number of threads available:    ', thread_num
        print *, 'Number of threads to use?'
        
        ! number of threads to use per rank
        read  *, num_threads
        print *, num_threads

        print '(a)', &
        '',&
        '|--------------------------------------------------------|',&
        '|                                                        |',&
        '|   Entering main program now. Please wait...            |',&
        '|                                                        |',&
        '|--------------------------------------------------------|',&
        '' 

        ! broadcast the data to all the other ranks
        call broadcasting (num_threads)

    end if

    ! set openmp in all ranks
    call omp_set_num_threads (num_threads)

    !-------------------------------------------------------------------
    ! Main (time) loop of the program
    !-------------------------------------------------------------------

    do tstep = 1, int(nt) + 1

        call stepper (tstep)

        if ( rank .eq. master ) then
            if (MODULO(tstep, int(comp)) .eq. 0) then

                call sea_ice_post (expno_str)
                if (MODULO(tstep, int(comp*50)) .eq. 0) then
                    print *, "Time step: ", tstep
                end if

            endif
        end if

    end do

    if ( rank .eq. master ) then
        tac = now()

        print*, "Total simulation time: ", delta_str(tac - tic)

        print '(a)', &
        '',&
        '|--------------------------------------------------------|',&
        '|                                                        |',&
        '|   Exiting main program now.                            |',&
        '|                                                        |',&
        '|--------------------------------------------------------|',&
        '' 
    end if

        !call execute_command_line("/aos/home/asavard/anaconda3/bin/python /storage/asavard/DEM/plots/video.py "//expno_str//' '//n_str)

        !tic = now()

        !print*, "Total video creation time: ", delta_str(tic - tac)

    call mpi_finalize(ierr)
    
end program ice
