using Libdl

lib = "libjulia_nvtx_callbacks.$(Libdl.dlext)"
try
    run(`cc -fPIC -shared callbacks.c -lnvToolsExt -o $lib`)
    @info "Success building $lib"
catch e
    @warn "Could not build $lib"
end