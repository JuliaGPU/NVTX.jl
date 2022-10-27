
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
    quote
        init!($mod.__nvtx_domain__, $(string(mod)))
    end
end

macro message(dom,msg)
    msg
end

macro message(dom, msg::String)
    sh = StringHandle()
    quote
        init!($sh, $dom, $msg)
    end
end

macro range(msg, expr)
    quote
        active = NVTX.isactive()
        if active
            domain = @domain($__module__)
            rangeid = range_start(domain; message=@message(domain, $msg))
        end
        try
            $(esc(expr))
        finally
            range_end(rangeid)
        end
    end
end