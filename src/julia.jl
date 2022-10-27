# convenience functions for using Julia


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
const GC_MESSAGE = Ref(StringHandle(C_NULL))
const GC_ALLOC_MESSAGE = Ref(StringHandle(C_NULL))
const GC_FREE_MESSAGE = Ref(StringHandle(C_NULL))
const GC_COLOR = Ref(UInt32(0))

function gc_cb_pre(full::Cint)
    # ideally we would pass `full` as a payload, but this causes allocations and
    # causes a problem when testing with threads
    range_push(GC_DOMAIN[]; category=reinterpret(UInt32, full), message=GC_MESSAGE[], color=GC_COLOR[])
    return nothing
end
function gc_cb_post(full::Cint)
    range_pop(GC_DOMAIN[])
    return nothing
end

function gc_cb_alloc(ptr::Ptr{Cvoid}, size::Csize_t)
    mark(GC_DOMAIN[]; message=GC_ALLOC_MESSAGE[], payload=size)
    return nothing
end
function gc_cb_free(ptr::Ptr{Cvoid})
    mark(GC_DOMAIN[]; message=GC_FREE_MESSAGE[])
    return nothing
end

"""
    NVTX.enable_gc_hooks(domain=Domain("Julia");
        gc="GC", alloc="alloc", free="free", color=Colors.colorant"brown")

Add NVTX hooks for the Julia garbage collector:
 - `gc` if not `nothing`, mark GC invocations as ranges
 - `alloc`: if not `nothing`, mark calls to alloc (payload will contain size)
 - `free`: if not `nothing`, mark calls to free
"""
function enable_gc_hooks(domain=Domain("Julia");
    alloc="alloc",
    free="free",
    gc="GC",
    color=Colors.colorant"brown",
    kwargs...)

    GC_DOMAIN[] = domain
    if !isnothing(gc)
        GC_MESSAGE[] = StringHandle(domain, gc)
    end
    if !isnothing(alloc)
        GC_ALLOC_MESSAGE[] = StringHandle(domain, alloc)
    end
    if !isnothing(free)
        GC_FREE_MESSAGE[] = StringHandle(domain, free)
    end
    if color isa Colors.Colorant
        color = Colors.ARGB32(color).color
    end
    GC_COLOR[] = color
    name_category(domain, 0, "partial")
    name_category(domain, 1, "full")
    ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_pre, Cvoid, (Cint,)), !isnothing(gc))
    ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_post, Cvoid, (Cint,)), !isnothing(gc))
    ccall(:jl_gc_set_cb_notify_external_alloc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_alloc, Cvoid, (Ptr{Cvoid},Csize_t)), !isnothing(alloc))
    ccall(:jl_gc_set_cb_notify_external_free, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_free, Cvoid, (Ptr{Cvoid},)), !isnothing(free))
    return nothing
end

