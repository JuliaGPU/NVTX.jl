module NVTX

import Colors

const libnvToolsExt = "libnvToolsExt"


const NSYS_ACTIVE = Ref{Bool}(false)

function __init__()
    NSYS_ACTIVE[] = haskey(ENV, "NSYS_PROFILING_SESSION_ID")
end

isactive() = NSYS_ACTIVE[]


mutable struct Domain
    ptr::Ptr{Cvoid}
end

function destroy(domain::Domain)
    ccall((:nvtxDomainDestroy, libnvToolsExt), Cvoid, (Ptr{Cvoid},), domain.ptr)
end

"""
    Domain(name::AbstractString)

Construct a new NVTX domain with `name`.

See [NVTX Domains](https://nvidia.github.io/NVTX/doxygen/index.html#DOMAINS).
"""
function Domain(name::AbstractString)
    domain = Domain(ccall((:nvtxDomainCreateA,libnvToolsExt), Ptr{Cvoid}, (Cstring,), name))
    finalizer(destroy, domain)
    return domain
end

const DEFAULT_DOMAIN = Domain(C_NULL)

struct StringHandle
    ptr::Ptr{Cvoid}
end

function StringHandle(domain::Domain, string::AbstractString)
    StringHandle(ccall((:nvtxDomainRegisterStringA, libnvToolsExt), Ptr{Cvoid},
        (Ptr{Cvoid},Cstring), domain.ptr, string))
end
StringHandle(string::AbstractString) = StringHandle(DEFAULT_DOMAIN, string)



struct EventAttributes
    version::UInt16
    size::UInt16
    category::UInt32
    colortype::Int32
    color::UInt32
    payloadtype::Int32
    reserved0::Int32
    payload::UInt64
    messagetype::Int32
    message::Ptr{Cvoid}
    messageref # for GC
end

payloadtype(::Nothing) = 0
payloadtype(::UInt64) = 1
payloadtype(::Int64) = 2
payloadtype(::Float64) = 3
payloadtype(::UInt32) = 4
payloadtype(::Int32) = 5
payloadtype(::Float32) = 6
payloadtype(_) = error("Unsupported payload type")

payloadval(::Nothing) = UInt64(0)
payloadval(payload::UInt64) = payload
payloadval(payload::Int64) = reinterpret(UInt64,payload)
payloadval(payload::Float64) = reinterpret(UInt64,payload)
# assumes little-endian
payloadval(payload::UInt32) = UInt64(payload)
payloadval(payload::Int32) = UInt64(reinterpret(UInt32,payload))
payloadval(payload::Float32) = UInt64(reinterpret(UInt32,payload))


function EventAttributes(;
    message=nothing,
    color=nothing,
    category=nothing,
    payload=nothing)

    if color isa Colors.Colorant
        color = Colors.ARGB32(color).color
    end

    if message isa AbstractString
        message = Base.cconvert(Cstring, message)
    end

    EventAttributes(
        3,                        # version
        fieldoffset(NVTX.EventAttributes, fieldcount(NVTX.EventAttributes)),  # size
        something(category, 0),   # category
        isnothing(color) ? 0 : 1, # colortype (1 = ARGB)
        something(color, 0),      # color
        payloadtype(payload),     # payloadtype
        0,                        # reserved0
        payloadval(payload),      # payload
        isnothing(message) ? 0 : message isa StringHandle ? 3 : 1,      # messagetype
        isnothing(message) ? C_NULL : message isa StringHandle ? message.ptr : Base.unsafe_convert(Cstring, message), # message
        message,
    )
end

"""
    NVTX.mark([domain::Domain]; message, color, payload, category)

Marks an instantaneous event in the application.

The `domain` positional argument allows specifying a custom [`Domain`](@ref),
otherise the default domain is used.

Optional keyword arguments:
- `message`: a text string
- `color`: a `Colorant` from the Colors.jl package, or an integer containing an ARGB32 value.
- `payload`: a 32- or 64-bit integer or floating point number
- `category`: a positive integer. See [`name_category`](@ref).
"""
function mark(;kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxMarkEx, libnvToolsExt), Cvoid,
        (Ptr{EventAttributes},), Ref(attr))
end
function mark(domain::Domain; kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxDomainMarkEx, libnvToolsExt), Cvoid,
    (Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
end


primitive type RangeId 64 end

"""
    NVTX.range_start([domain::Domain]; message, color, payload, category)

Starts a process range.

Returns a `RangeId` value, which should be passed to [`range_end`](@ref).

See [`mark`](@ref) for the keyword arguments.
"""
function range_start(; kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxRangeStartEx, libnvToolsExt), RangeId,(Ptr{EventAttributes},), Ref(attr))
end
function range_start(domain::Domain; kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxDomainRangeStartEx, libnvToolsExt), RangeId,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
end

"""
    NVTX.range_end(range::RangeId)

Ends a process range.
"""
function range_end(range::RangeId)
    ccall((:nvtxRangeEnd, libnvToolsExt), Cvoid,(RangeId,), range)
end

"""
    range_push([domain]; message, color, payload, category)

Starts a nested thread range. Returns the 0-based level of range being started (the level is per-domain).

Must be completed with [`range_pop`](@ref).

!!! note
    This does not appear to work correctly.

See [`mark`](@ref) for the keyword arguments.
"""
function range_push(; kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxRangePushEx, libnvToolsExt), Cint,(Ptr{EventAttributes},), Ref(attr))
end
function range_push(domain::Domain; kwargs...)
    attr = EventAttributes(;kwargs...)
    ccall((:nvtxDomainRangePushEx, libnvToolsExt), Cint,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
end

"""
    range_pop([domain::Domain])

Ends a nested thread range. The `domain` argument must match that from [`range_push`](@ref).

Returns the 0-based level of the range being ended.
"""
function range_pop()
    ccall((:nvtxRangePop, libnvToolsExt), Cint, ())
end
function range_pop(domain::Domain)
    ccall((:nvtxDomainRangePop, libnvToolsExt), Cint, (Ptr{Cvoid},), domain.ptr)
end


"""
    name_category([domain::Domain,] category::Integer, name::AbstractString)

Annotate an NVTX `category` with `name`. If a [`Domain`](@ref) argument is
provided, then annotation only applies within that domain.
"""
function name_category(category::Integer, name::AbstractString)
    ccall((:nvtxNameCategoryA, libnvToolsExt), Cvoid,
    (UInt32, Cstring), category, name)
end
function name_category(domain::Domain, category::Integer, name::AbstractString)
    ccall((:nvtxDomainNameCategoryA, libnvToolsExt), Cvoid,
    (Ptr{Cvoid}, UInt32, Cstring), domain.ptr, category, name)
end


"""
    name_os_thread(threadid::Integer, name::AbstractString)

Attach a name to an operating system thread. `threadid` is the OS thread ID, returned by [`gettid`](@ref).
"""
function name_os_thread(threadid::Integer, name::AbstractString)
    ccall((:nvtxNameOsThreadA, libnvToolsExt), Cvoid,
        (UInt32, Cstring), threadid, name)
end

@static if Sys.islinux() && Sys.ARCH == :x86_64
    gettid() = ccall(:syscall, UInt32, (Clong, Clong...), 186)
elseif Sys.islinux() && Sys.ARCH == :aarch64
    gettid() = ccall(:syscall, UInt32, (Clong, Clong...), 178)
elseif Sys.iswindows()
    gettid() = ccall(:GetCurrentThreadId, UInt32,())
end

"""
    name_threads_julia()

Name the threads owned by the Julia process "julia thread 1", "julia thread 2", etc.
"""
function name_threads_julia()
    Threads.@threads :static for t = 1:Threads.nthreads()
        name_os_thread(gettid(), "julia thread $(Threads.threadid())")
    end
end


const GC_DOMAIN = Ref(Domain(C_NULL))
const GC_ATTR = Ref(EventAttributes())

function gc_cb_pre(full::Cint)
    # ideally we would pass `full` as a payload, but this causes allocations and
    # causes a problem when testing with threads
    ccall((:nvtxDomainRangePushEx, libnvToolsExt), Cint,(Ptr{Cvoid},Ptr{EventAttributes}), GC_DOMAIN[].ptr, GC_ATTR)
    return nothing
end
function gc_cb_post(full::Cint)
    ccall((:nvtxDomainRangePop, libnvToolsExt), Cint, (Ptr{Cvoid},), GC_DOMAIN[].ptr)
    return nothing
end

"""
    NVTX.enable_gc_hooks(domain=Domain("Julia"), message="GC")

Add NVTX hooks for the Julia garbage collector.
"""
function enable_gc_hooks(domain=Domain("Julia"); message=StringHandle(domain, "GC"), color=Colors.colorant"brown", kwargs...)
    GC_DOMAIN[] = domain
    GC_ATTR[] = EventAttributes(;message, color, kwargs...)
    ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_pre, Cvoid, (Cint,)), true)
    ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_post, Cvoid, (Cint,)), true)
end


end # module
