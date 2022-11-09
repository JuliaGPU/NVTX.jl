# NVTX.jl

[![CI](https://github.com/simonbyrne/NVTX.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/simonbyrne/NVTX.jl/actions/workflows/CI.yml)

Julia bindings to the [NVIDIA Tools Extension Library (NVTX)](https://nvidia.github.io/NVTX/doxygen/index.html) for instrumenting Julia code for use with the [Nsight systems profiler](https://developer.nvidia.com/nsight-systems).

## Requirements

This requires the NVTX library be installed, as well as [Nsight systems](https://docs.nvidia.com/nsight-systems/UserGuide/index.html).\
Both are included in the [NVIDIA CUDA toolkit](https://developer.nvidia.com/cuda-toolkit) (no GPU is required). Currently only Linux is supported.

It can be loaded on any platform, even without the NVTX library, and so can safely be included as a dependency in other packages.

## Usage

There are two convenience macros which can be used to annotate instrumentation for instantaneous events (`NVTX.@mark`) or ranges (`NVTX.@range`):

```julia
NVTX.@mark "my message"

NVTX.@range "my message" begin
    # code to measure
end
```
These macros can safely be used if the profiler is not active, or not even installed, and so are safe to include in package code.

To run the Nsight systems profiler, use
```
nsys --trace=nvtx julia script.jl
```

### Julia runtime

There are some additional functions for instrumenting the Julia runtime:

- `NVTX.name_threads_julia()` will name the threads used by Julia using Julia's internal numbering (`julia thread 1`, `julia thread 2`, etc.)
- `NVTX.enable_gc_hooks()` will instrument the Julia garbage collector (GC).

These functions can only be called if the profiler is active. Use `NVTX.isactive()` to determine if this is the case.

### MPI

When using with MPI, the MPI launcher can be placed _inside_ the nsys call
```
nsys profile --trace=nvtx,mpi --mpi-impl=openmpi mpiexec -n 2 julia --project mpi.jl
```
which will generate one report for the whole run, or outside
```
mpiexec -n 2 nsys profile --trace=nvtx,mpi --mpi-impl=openmpi --output=report.%q{OMPI_COMM_WORLD_RANK} julia --project mpi.jl
```
which will generate a report for each MPI process, and can be opened as a "multi-report view".


#### Notes
The profiler itself has some overhead: this is only visible in the report if using the launcher outside the `nsys` call.

Overhead can be reduced by allocating an additional CPU core per MPI process for the profiler (e.g. via the `--cpus-per-task` option in Slurm). To ensure that these are scheduled correctly, it is best to "bind" the CPU cores per task. If launching using `srun`, then use the `--cpu-bind=cores`; if launching using Open MPI `mpiexec`, use `--map-by node:PE=$cpus_per_task --bind-to core`.


#### Example

<img width="1904" alt="report1" src="https://user-images.githubusercontent.com/187980/182362221-aea7eb12-a736-406b-807f-1e1c46c406d0.png">
