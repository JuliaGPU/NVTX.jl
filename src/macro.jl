
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

const custom_domain = NVTX.@domain "name"


=#



function defineconsts(mod)
    if !isdefined(mod, :__nvtx_domain__)
        domain = Domain()
        @eval mod begin
            const __nvtx_domain__ = $domain
            const __nvtx_hooks__ = []
        end
        if isactive()
            init!(domain, string(mod))
        end
    end
end
definestring(dom, msg) = msg
function definestring(dom, msg::String)
    sh = StringHandle()
    push!(__nvtx_hooks__, () -> init!(sh, dom, msg))
    if isactive()
        init!(sh, dom, msg)
    end
    return sh
end

macro init()
    defineconsts(__module__)
    quote
        if isactive()
            init!($__module__.__nvtx_domain__, $(string(__module__)))
            while !isempty($__module__.__nvtx_hooks__)
                f = popfirst!($__module__.__nvtx_hooks__)
                f()
            end
        end
    end
end

"""
    @domain name

Define a new domain
"""
macro domain(name::AbstractString)
    defineconsts(mod)
    dom = Domain()
    init() = init!(dom, name)
    push!(__module__.__nvtx_hooks__, init)
    if isactive()
        init()
    end
    return dom
end

macro string(domain, str)
    defineconsts(mod)
    if str isa AbstractString
        _domain = domain
        if domain isa Symbol && isconst(__module__, domain)
            _domain = eval(__module, domain)
        end
        if _domain isa Domain
            sh = StringHandle()
            init() = init!(sh, _domain, str)
            push!(__module__.__nvtx_hooks__, init)
            if isactive()
                init()
            end
            return sh
        end
    end
    return esc(str)
end

macro domain()
    :(@domain($__module__))
end


macro mark(msg)
    defineconsts(__module__)
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