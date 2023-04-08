using Documenter
using NVTX

makedocs(
    sitename = "NVTX",
    format = Documenter.HTML(),
    modules = [NVTX],
    pages = [
        "index.md",
        "api.md",
        "tips.md",
    ]
)

deploydocs(
    repo = "https://github.com/JuliaGPU/NVTX.jl",
    target = "build",
    push_preview = true,
    devbranch = "main",
    forcepush = true,
)
