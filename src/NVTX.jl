module NVTX

const libnvToolsExt = "libnvToolsExt"

mutable struct Domain
    ptr::Ptr{Cvoid}
end

function destroy(domain::Domain)
    ccall((:nvtxDomainDestroy, libnvToolsExt), Cvoid, (Ptr{Cvoid},), domain.ptr)
end

"""
    Domain(name::AbstractString)

Construct a new NVTX domain.

See [NVTX Domains](https://nvidia.github.io/NVTX/doxygen/index.html#DOMAINS).
"""
function Domain(name::AbstractString)
    domain = Domain(ccall((:nvtxDomainCreateA,libnvToolsExt), Ptr{Cvoid}, (Cstring,), name))
    finalizer(destroy, domain)
    return domain
end

const DEFAULT_DOMAIN = Domain(C_NULL)



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


function unsafe_EventAttributes(;
    message=nothing,
    color=nothing,
    category=nothing,
    payload=nothing)

    EventAttributes(
        3,                        # version
        sizeof(EventAttributes),  # size
        something(category, 0),   # category
        isnothing(color) ? 0 : 1, # colortype (1 = ARGB)
        something(color, 0),      # color
        payloadtype(payload),     # payloadtype
        0,                        # reserved0
        payloadval(payload),      # payload
        isnothing(message) ? 0 : 1,            # messagetype
        Base.unsafe_convert(Cstring, message), # message
    )
end

"""
    NVTX.mark([domain::Domain]; message, color, payload, category)

Marks an instantaneous event in the application.

The `domain` positional argument allows specifying a custom [`Domain`](@ref),
otherise the default domain is used.

Optional keyword arguments:
- `message`: a text string
- `color`:
- `payload`: a 32- or 64-bit integer or floating point number
- `category`: a positive integer. See [`name_category`](@ref).
"""
function mark(domain::Domain; kwargs...)
  GC.@preserve kwargs begin
      attr = unsafe_EventAttributes(;kwargs...)
      ccall((:nvtxDomainMarkEx, libnvToolsExt), Cvoid,
        (Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
  end
end
function mark(;kwargs...)
    GC.@preserve kwargs begin
        attr = unsafe_EventAttributes(;kwargs...)
        ccall((:nvtxMarkEx, libnvToolsExt), Cvoid,
            (Ptr{EventAttributes},), Ref(attr))
    end
end


primitive type RangeId 64 end

"""
    NVTX.range_start([domain::Domain]; message, color, payload, category)

Starts a process range.

Returns a `RangeId` value, which should be passed to [`range_end`](@ref).

See [`mark`](@ref) for the keyword arguments.
"""
function range_start(domain::Domain; kwargs...)
    GC.@preserve kwargs begin
      attr = unsafe_EventAttributes(;kwargs...)
      ccall((:nvtxDomainRangeStartEx, libnvToolsExt), RangeId,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
    end
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

See [`mark`](@ref) for the keyword arguments.
"""
function range_push(domain::Domain; kwargs...)
    GC.@preserve kwargs begin
      attr = unsafe_EventAttributes(;kwargs...)
      ccall((:nvtxDomainRangePushEx, libnvToolsExt), Cint,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
    end
end

"""
    range_pop([domain::Domain])

Ends a nested thread range. The `domain` argument must match that from [`range_push`](@ref).

Returns the 0-based level of the range being ended.
"""
function range_pop(domain::Domain)
    ccall((:nvtxRangePop, libnvToolsExt), Cint, (Ptr{Cvoid},), domain.ptr)
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
    (Domain, UInt32, Cstring), domain.ptr, category, name)
end







end # module
