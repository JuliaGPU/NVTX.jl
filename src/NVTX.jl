module NVTX

import Colors

const libnvToolsExt = "libnvToolsExt"


const NSYS_ACTIVE = Ref{Bool}(false)

"""
    NVTX.isactive()

Determine if Nsight Systems profiling is currently active.
"""
isactive() = NSYS_ACTIVE[]

function __init__()
    NSYS_ACTIVE[] = haskey(ENV, "NSYS_PROFILING_SESSION_ID")
end

include("api.jl")
include("julia.jl")
include("macro.jl")

end # module
