using MPI, NVTX

MPI.Init()

NVTX.range_gc()

outer_range = NVTX.range_start()

MPI.Barrier(MPI.COMM_WORLD)

MPI.Allreduce(rand(10), +, MPI.COMM_WORLD)

GC.gc()

NVTX.range_end(outer_range)
