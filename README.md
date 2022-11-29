# NVTX.jl

[![CI](https://github.com/simonbyrne/NVTX.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/simonbyrne/NVTX.jl/actions/workflows/CI.yml)

Julia bindings to the [NVIDIA Tools Extension Library (NVTX)](https://nvidia.github.io/NVTX/doxygen/index.html) for instrumenting Julia code for use with the [Nsight systems profiler](https://developer.nvidia.com/nsight-systems).

## Requirements

NVTX.jl now bundles the NVTX library for supported platforms, however you will need to install the [NVIDIA Nsight Systems](https://developer.nvidia.com/nsight-systems) to actually run the profiler: it is available for Linux (x86_64, Aarch64, Power) and Windows (x86_64), and the resulting profiles can be viewed on Linux, Windows and MacOS.

Currently only x86_64 Linux has been tested, but other systems _should_ work: please open an issue if you have problems.

NVTX.jl can be loaded on any platform, even those without the NVTX library, and so can safely be included as a package dependency.

## Usage

There are two convenience macros which can be used to instrument instantaneous events (`NVTX.@mark`) or ranges (`NVTX.@range`):

```julia
NVTX.@mark "my message"

NVTX.@range "my message" begin
    # code to measure
end
```
These macros can safely be used if the profiler is not active, or not even installed, and so are safe to include in package code.

To run the Nsight Systems profiler, use
```
nsys profile julia script.jl
```

See [Nsight Systems User Manual](https://docs.nvidia.com/nsight-systems/UserGuide/index.html) for more information.

### Julia runtime

There are some additional functions for instrumenting the Julia runtime:

- `NVTX.name_threads_julia()` will name the threads used by Julia using Julia's internal numbering (`julia thread 1`, `julia thread 2`, etc.)
  - This is now called autoatically at initialization.
- `NVTX.enable_gc_hooks()` will instrument the Julia garbage collector (GC).
  - This can also be enabled by setting `JULIA_NVTX_CALLBACKS=gc`.

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
