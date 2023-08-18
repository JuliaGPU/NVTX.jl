module NVTX

import Colors, Libdl
using Preferences, NVTX_jll, JuliaNVTXCallbacks_jll

const enabled = @load_preference("enable", NVTX_jll.is_available())

const NSYS_ACTIVE = Ref{Bool}(false)

"""
    NVTX.isactive()

Determine if Nsight Systems profiling is currently active.

    !!! detail
        This is deprecated.
"""
isactive() = NSYS_ACTIVE[]

function __init__()
    if haskey(ENV, "NSYS_PROFILING_SESSION_ID")
        NSYS_ACTIVE[] = true
    end
    initialize()
    name_threads_julia()
    callbacks = split(get(ENV, "JULIA_NVTX_CALLBACKS", ""), [',','|'])
    enable_gc_hooks(;
        gc="gc" in callbacks,
        alloc="alloc" in callbacks,
        free="free" in callbacks
    )
end

include("api.jl")
include("julia.jl")
include("macro.jl")

end # module
