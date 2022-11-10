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

# domain used for instrumenting Julia runtime
const JULIA_DOMAIN = Domain("Julia")
const GC_MESSAGE = StringHandle(JULIA_DOMAIN, "GC")
const GC_ALLOC_MESSAGE = StringHandle(JULIA_DOMAIN, "alloc")
const GC_FREE_MESSAGE = StringHandle(JULIA_DOMAIN, "free")
const GC_COLOR = Ref{UInt32}(Colors.ARGB32(Colors.colorant"brown").color)

function gc_cb_pre(full::Cint)
    range_push(JULIA_DOMAIN;
        category=reinterpret(UInt32, full),
        message=GC_MESSAGE,
        color=GC_COLOR[])
    return nothing
end
function gc_cb_post(full::Cint)
    range_pop(JULIA_DOMAIN)
    return nothing
end
function gc_cb_alloc(ptr::Ptr{Cvoid}, size::Csize_t)
    mark(JULIA_DOMAIN;
        message=GC_ALLOC_MESSAGE, payload=size)
    return nothing
end
function gc_cb_free(ptr::Ptr{Cvoid})
    mark(JULIA_DOMAIN;
        message=GC_FREE_MESSAGE)
    return nothing
end

"""
    NVTX.enable_gc_hooks(;gc=true, alloc=false, free=false)

Add NVTX hooks for the Julia garbage collector:
 - `gc`: instrument GC invocations as ranges
 - `alloc`: instrument calls to alloc as marks (payload will contain size)
 - `free`: instrument calls to free as marks
"""
function enable_gc_hooks(;gc::Bool=true, alloc::Bool=false, free::Bool=false)
    if gc || alloc || free
        init!(JULIA_DOMAIN)
        unsafe_store!(cglobal((:julia_domain,libjulia_nvtx_cb),Ptr{Cvoid}), JULIA_DOMAIN.ptr)
        unsafe_store!(cglobal((:gc_color,libjulia_nvtx_cb),UInt32), GC_COLOR[])
    end
    if gc
        init!(GC_MESSAGE)
        unsafe_store!(cglobal((:gc_message,libjulia_nvtx_cb),Ptr{Cvoid}), GC_MESSAGE.ptr)
        name_category(JULIA_DOMAIN, 0, "partial")
        name_category(JULIA_DOMAIN, 1, "full")
    end
    if alloc
        init!(GC_ALLOC_MESSAGE)
    end
    if free
        init!(GC_FREE_MESSAGE)
    end
    ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_pre, Cvoid, (Cint,)), gc)
    ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_post, Cvoid, (Cint,)), gc)
    ccall(:jl_gc_set_cb_notify_external_alloc, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_alloc, Cvoid, (Ptr{Cvoid},Csize_t)), alloc)
    ccall(:jl_gc_set_cb_notify_external_free, Cvoid, (Ptr{Cvoid}, Cint),
        @cfunction(gc_cb_free, Cvoid, (Ptr{Cvoid},)), free)
    return nothing
end

