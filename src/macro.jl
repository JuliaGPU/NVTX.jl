
#=

# idea: set default domain based on current module
const DOMAIN_CACHE = Dict{Module,Domain}()

function local_domain(mod::Module)
    get!(DOMAINS, mod) do
        Domain(string(domain))
    end
end
=#
#=

NVTX.@range "message" color=... payload=... category=... expr

- operate in a domain scoped to the current module
- minimal overhead if NVTX is not active
- either:
  - lazily initialize
  - or push to an initialization queue
- use a StringHandle if message is a `String` (and not an expression)
- have an option to use a non-default domain
=#

"""
    @domain(mod)

Get the default domain for the module `mod`, initializing if necessary.
"""
macro domain(mod)
    if !isdefined(mod, :__nvtx_domain__)
        @eval(mod, const __nvtx_domain__ = $(Domain()))
    end
    :(init!($mod.__nvtx_domain__, $(string(mod))))
end

macro message(dom, msg)
    sh = StringHandle()
    :(init!($sh, $dom, $(esc(msg))))
end

macro mark(msg)
    strmsg = msg isa String ? :(@message(domain, $msg)) : esc(msg)
    quote
        active = isactive()
        if active
            domain = @domain($__module__)
            mark(domain; message=$strmsg)
        end
    end
end


macro range(msg, expr)
    strmsg = msg isa String ? :(@message(domain, $msg)) : esc(msg)
    quote
        active = isactive()
        if active
            domain = @domain($__module__)
            rangeid = range_start(domain; message=$strmsg)
        end
        try
            $(esc(expr))
        finally
            range_end(rangeid)
        end
    end
end