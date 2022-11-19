using Libdl

lib = "libjulia_nvtx_callbacks.$(Libdl.dlext)"
try
    run(`nvcc -Xcompiler -fPIC -shared callbacks.c -o $lib`)
    @info "Success building $lib"
catch e
    @warn "Could not build $lib"
end
