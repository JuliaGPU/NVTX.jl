# NVTX.jl

Julia bindings to the [NVIDIA Tools Extension Library (NVTX)](https://nvidia.github.io/NVTX/doxygen/index.html).

## Requirements

This requires the NVTX library be installed, as well as [Nsight systems](https://docs.nvidia.com/nsight-systems/UserGuide/index.html).\
Both are included in the NVIDIA CUDA toolkit (no GPU is required).

Currently only Linux is supported.

## Usage

```
nsys --trace=nvtx julia script.jl
```

### MPI

When using with MPI, the MPI launcher can be place _inside_ the nsys call
```
nsys profile --trace=nvtx,mpi --mpi-impl=openmpi mpiexec -n 2 julia --project mpi.jl
```
which will generate one report for the whole run, or outside
```
mpiexec -n 2 nsys profile --trace=nvtx,mpi --mpi-impl=openmpi --output=report.%q{OMPI_COMM_WORLD_RANK} julia --project mpi.jl
```
which will generate a report for each MPI process, and can be opened as a "multi-report view". 


#### Notes
The compiler itself has some overhead: this is only visible in the report if using the launcher outside the `nsys` call.

Overhead can be reduced by allocating an additional CPU core per MPI process for the profiler (e.g. via the `--cpus-per-task` option in Slurm). To ensure that these are scheduled correctly, it is best to "bind" the CPU cores per task. If launching using `srun`, then use the `--cpu-bind=cores`; if launching using Open MPI `mpiexec`, use `--map-by node:PE=$cpus_per_task --bind-to core`.


#### Example

<img width="1904" alt="report1" src="https://user-images.githubusercontent.com/187980/182362221-aea7eb12-a736-406b-807f-1e1c46c406d0.png">
