module NVTX

import Colors

const libnvToolsExt = "libnvToolsExt"


const NSYS_ACTIVE = Ref{Bool}(false)
isactive() = NSYS_ACTIVE[]

const init_callbacks = []

function __init__()
    NSYS_ACTIVE[] = haskey(ENV, "NSYS_PROFILING_SESSION_ID")
    for f in init_callbacks
        f()
    end
end


include("api.jl")
include("julia.jl")
include("macro.jl")

end # module
