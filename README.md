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

