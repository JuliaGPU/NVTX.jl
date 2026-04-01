using CEnum

"""
    initialize()

Force NVTX library to initialize. The first call to any NVTX API function will
automatically initialize the entire API. This can make the first call much
slower than subsequent calls.
"""
function initialize()
    ccall((:nvtxInitialize, libnvToolsExt), Cvoid, (Ptr{Cvoid},), C_NULL)
end


mutable struct Domain
    ptr::Ptr{Cvoid}
    name::String
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
    domain = Domain(C_NULL, name)
    if isactive()
        init!(domain)
    end
    return domain
end

function init!(domain::Domain)
    if domain.ptr == C_NULL && domain.name != ""
        domain.ptr = ccall((:nvtxDomainCreateA,libnvToolsExt), Ptr{Cvoid}, (Cstring,), domain.name)
        finalizer(destroy, domain)
    end
    return domain
end

const DEFAULT_DOMAIN = Domain(C_NULL,"")

mutable struct StringHandle
    ptr::Ptr{Cvoid}
    domain::Domain
    string::String
end

"""
    StringHandle(domain::NVTX.Domain, string::AbstractString)

Register `string` with `domain`, returning a `StringHandle` object.

Registered strings are intended to increase performance by lowering
instrumentation overhead.
"""
function StringHandle(domain::Domain, string::AbstractString)
    sh = StringHandle(C_NULL, domain, string)
    if isactive()
        init!(sh)
    end
    return sh
end

function init!(sh::StringHandle)
    if sh.ptr == C_NULL
        init!(sh.domain)
        sh.ptr = ccall((:nvtxDomainRegisterStringA, libnvToolsExt), Ptr{Cvoid},
            (Ptr{Cvoid},Cstring), sh.domain.ptr, sh.string)
    end
    return sh
end

@cenum nvtxColorType_t::Int32 begin
    NVTX_COLOR_UNKNOWN  = 0
    NVTX_COLOR_ARGB     = 1
end

@cenum nvtxMessageType_t::Int32 begin
    NVTX_MESSAGE_UNKNOWN          = 0
    NVTX_MESSAGE_TYPE_ASCII       = 1
    NVTX_MESSAGE_TYPE_UNICODE     = 2
    #= NVTX_VERSION_2 =#
    NVTX_MESSAGE_TYPE_REGISTERED  = 3
end

@cenum nvtxPayloadType_t::Int32 begin
    NVTX_PAYLOAD_UNKNOWN = 0
    NVTX_PAYLOAD_TYPE_UNSIGNED_INT64 = 1
    NVTX_PAYLOAD_TYPE_INT64 = 2
    NVTX_PAYLOAD_TYPE_DOUBLE = 3
    #= NVTX_VERSION_2 =#
    NVTX_PAYLOAD_TYPE_UNSIGNED_INT32 = 4
    NVTX_PAYLOAD_TYPE_INT32 = 5
    NVTX_PAYLOAD_TYPE_FLOAT = 6
end

struct EventAttributes
    version::UInt16
    size::UInt16
    category::UInt32
    colortype::nvtxColorType_t
    color::UInt32
    payloadtype::nvtxPayloadType_t
    reserved0::Int32
    payload::UInt64
    messagetype::nvtxMessageType_t
    message::Ptr{Cvoid}
end

payloadtype(::Nothing) = NVTX_PAYLOAD_UNKNOWN
payloadtype(::UInt64) = NVTX_PAYLOAD_TYPE_UNSIGNED_INT64
payloadtype(::Int64) = NVTX_PAYLOAD_TYPE_INT64
payloadtype(::Float64) = NVTX_PAYLOAD_TYPE_DOUBLE
payloadtype(::UInt32) = NVTX_PAYLOAD_TYPE_UNSIGNED_INT32
payloadtype(::Int32) = NVTX_PAYLOAD_TYPE_INT32
payloadtype(::Float32) = NVTX_PAYLOAD_TYPE_FLOAT
payloadtype(_) = error("Unsupported payload type")

payloadval(::Nothing) = UInt64(0)
payloadval(payload::UInt64) = payload
payloadval(payload::Int64) = reinterpret(UInt64, payload)
payloadval(payload::Float64) = reinterpret(UInt64, payload)
# assumes little-endian
payloadval(payload::UInt32) = UInt64(payload)
payloadval(payload::Int32) = UInt64(reinterpret(UInt32, payload))
payloadval(payload::Float32) = UInt64(reinterpret(UInt32, payload))

# This is extended in the Colors extension for Colorant support
_normalize_color(x) = x

function event_attributes(;
    message=nothing,
    color=nothing,
    category=nothing,
    payload=nothing)

    color = _normalize_color(color)

    if message isa AbstractString
        message = Base.cconvert(Cstring, message)
    end
    # This will be GC.preserved by the caller
    msgref = message

    if isnothing(message)
        message_type = NVTX_MESSAGE_UNKNOWN
        message = C_NULL
    elseif message isa StringHandle
        message_type = NVTX_MESSAGE_TYPE_REGISTERED
        message = message.ptr
    else
        message_type = NVTX_MESSAGE_TYPE_ASCII
        message = Base.unsafe_convert(Cstring, message)
    end

    EventAttributes(
        3,                        # version
        sizeof(EventAttributes),  # size
        something(category, 0),   # category
        isnothing(color) ? NVTX_COLOR_UNKNOWN : NVTX_COLOR_ARGB,
        something(color, 0),      # color
        payloadtype(payload),     # payloadtype
        0,                        # reserved0
        payloadval(payload),      # payload
        message_type,             # messagetype
        message, # message
    ), msgref
end

"""
    NVTX.mark([domain::Domain]; message, color, payload, category)

Marks an instantaneous event in the application.

The `domain` positional argument allows specifying a custom [`Domain`](@ref),
otherwise the default domain is used.

Optional keyword arguments:
- `message`: a text string, or [`StringHandle`](@ref) object.
- `color`: a `Colorant` from the Colors.jl package, or an integer containing an
  ARGB32 value.
- `payload`: a value of one of the following types: `UInt64`, `Int64`, `UInt32`,
  `Int32`, `Float64`, `Float32`.
- `category`: a positive integer. See [`name_category`](@ref).
"""
function mark(attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxMarkEx, libnvToolsExt), Cvoid,
            (Ptr{EventAttributes},), Ref(attr))
    end
end
function mark(domain::Domain, attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxDomainMarkEx, libnvToolsExt), Cvoid,
        (Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
    end
end
mark(;kwargs...) = mark(event_attributes(;kwargs...)...)
mark(domain::Domain; kwargs...) = mark(domain, event_attributes(;kwargs...)...)


primitive type RangeId 64 end

"""
    NVTX.range_start([domain::Domain]; message, color, payload, category)

Starts a process range.

Returns a `RangeId` value, which should be passed to [`range_end`](@ref).

See [`mark`](@ref) for the keyword arguments.
"""
function range_start(attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxRangeStartEx, libnvToolsExt), RangeId,(Ptr{EventAttributes},), Ref(attr))
    end
end
function range_start(domain::Domain, attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxDomainRangeStartEx, libnvToolsExt), RangeId,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
    end
end
range_start(; kwargs...) = range_start(event_attributes(;kwargs...)...)
range_start(domain::Domain; kwargs...) = range_start(domain, event_attributes(;kwargs...)...)

"""
    NVTX.range_end(range::RangeId)

Ends a process range started with [`range_start`](@ref).
"""
function range_end(range::RangeId)
    ccall((:nvtxRangeEnd, libnvToolsExt), Cvoid,(RangeId,), range)
end

"""
    range_push([domain]; message, color, payload, category)

Starts a nested thread range. Returns the 0-based level of range being started
(the level is per-domain).

Must be completed with [`range_pop`](@ref) with the same `domain` argument.

See [`mark`](@ref) for the keyword arguments.

!!! warning

    Both `range_push` and `range_pop` must be called from the same thread: this is
    difficult to guarantee in Julia as tasks can be migrated between threads when they
    are re-scheduled, so we encourage using [`range_start`](@ref)/[`range_end`](@ref)
    instead.

"""
function range_push(attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxRangePushEx, libnvToolsExt), Cint,(Ptr{EventAttributes},), Ref(attr))
    end
end
function range_push(domain::Domain, attr::EventAttributes, msgref=nothing)
    GC.@preserve msgref begin
        ccall((:nvtxDomainRangePushEx, libnvToolsExt), Cint,(Ptr{Cvoid},Ptr{EventAttributes}), domain.ptr, Ref(attr))
    end
end
range_push(; kwargs...) = range_push(event_attributes(;kwargs...)...)
range_push(domain::Domain; kwargs...) = range_push(domain, event_attributes(;kwargs...)...)

"""
    range_pop([domain::Domain])

Ends a nested thread range created by [`range_push`](@ref) on `domain`.

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

See also [`@category`](@ref)
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
