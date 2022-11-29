# convenience functions for using Julia
@static if Sys.islinux()
    if Sys.ARCH == :x86_64
        gettid() = ccall(:syscall, UInt32, (Clong, Clong...), 186)
    elseif Sys.ARCH == :aarch64
        gettid() = ccall(:syscall, UInt32, (Clong, Clong...), 178)
    elseif Sys.ARCH == :powerpc64le || Sys.ARCH == :ppc64le
        gettid() = ccall(:syscall, UInt32, (Clong, Clong...), 207)
    end
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
const GC_ALLOC_COLOR = Ref{UInt32}(Colors.ARGB32(Colors.colorant"goldenrod1").color)
const GC_FREE_COLOR = Ref{UInt32}(Colors.ARGB32(Colors.colorant"dodgerblue").color)

"""
    NVTX.enable_gc_hooks(;gc=true, alloc=false, free=false)

Add NVTX hooks for the Julia garbage collector:
 - `gc`: instrument GC invocations as ranges
 - `alloc`: instrument calls to alloc as marks (payload will contain size)
 - `free`: instrument calls to free as marks
"""
function enable_gc_hooks(;gc::Bool=true, alloc::Bool=false, free::Bool=false)
    if !isfile(libjulia_nvtx_callbacks)
        error("""
            libjulia_nvtx_callbacks library not found. Run

              using Pkg; Pkg.build("NVTX"; verbose=true)
            """)
    end
    if gc || alloc || free
        init!(JULIA_DOMAIN)
        unsafe_store!(cglobal((:julia_domain,libjulia_nvtx_callbacks),Ptr{Cvoid}), JULIA_DOMAIN.ptr)
    end
    if gc
        init!(GC_MESSAGE)
        unsafe_store!(cglobal((:gc_message,libjulia_nvtx_callbacks),Ptr{Cvoid}), GC_MESSAGE.ptr)
        unsafe_store!(cglobal((:gc_color,libjulia_nvtx_callbacks),UInt32), GC_COLOR[])
        # https://github.com/JuliaLang/julia/blob/v1.8.3/src/julia.h#L879-L883
        name_category(JULIA_DOMAIN, 1, "auto")
        name_category(JULIA_DOMAIN, 1, "full")
        name_category(JULIA_DOMAIN, 2, "incremental")
    end
    if alloc
        init!(GC_ALLOC_MESSAGE)
        unsafe_store!(cglobal((:gc_alloc_message,libjulia_nvtx_callbacks),Ptr{Cvoid}), GC_ALLOC_MESSAGE.ptr)
    end
    if free
        init!(GC_FREE_MESSAGE)
        unsafe_store!(cglobal((:gc_free_message,libjulia_nvtx_callbacks),Ptr{Cvoid}), GC_FREE_MESSAGE.ptr)
    end

    ccall(:jl_gc_set_cb_pre_gc, Cvoid, (Ptr{Cvoid}, Cint),
        cglobal((:nvtx_julia_gc_cb_pre,libjulia_nvtx_callbacks)), gc)
    ccall(:jl_gc_set_cb_post_gc, Cvoid, (Ptr{Cvoid}, Cint),
        cglobal((:nvtx_julia_gc_cb_post,libjulia_nvtx_callbacks)), gc)
    ccall(:jl_gc_set_cb_notify_external_alloc, Cvoid, (Ptr{Cvoid}, Cint),
        cglobal((:nvtx_julia_gc_cb_alloc,libjulia_nvtx_callbacks)), alloc)
    ccall(:jl_gc_set_cb_notify_external_free, Cvoid, (Ptr{Cvoid}, Cint),
        cglobal((:nvtx_julia_gc_cb_free,libjulia_nvtx_callbacks)), free)
    return nothing
end

