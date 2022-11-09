# determine the domain and attributes for the macro call
function domain_attrs(__module__, __source__, args)
    domain = nothing
    message = nothing
    color = nothing
    category = nothing
    payload = nothing
    # if not a keyword, first arg is the message
    if length(args) >= 1
        arg = args[1]
        if !(arg isa Expr && arg.head == :(=))
            message = args[1]
            args = args[2:end]
        end
    end
    for arg in args
        if !(arg isa Expr && arg.head == :(=))
            error("$arg is not a keyword")
        end
        kw, val = arg.args
        if kw == :domain && isnothing(domain)
            domain = val
        elseif kw == :message && isnothing(message)
            message = val
        elseif kw == :color && isnothing(color)
            color = val
        elseif kw == :category && isnothing(category)
            category = val
        elseif kw == :payload && isnothing(payload)
            payload = val
        else
            if kw in [:domain, :message, :color, :category, :payload]
                error("$kw already defined")
            else
                error("invalid keyword $kw")
            end
        end
    end
    if isnothing(domain)
        if !isdefined(__module__, :__nvtx_domain__)
            @eval __module__ begin
                const __nvtx_domain__ = $(Domain(string(__module__)))
            end
        end
        domain = __module__.__nvtx_domain__
    end
    if isnothing(message)
        message = "$(__source__.file):$(__source__.line)"
    end
    if isnothing(color)
        # generate a unique color from the message
        color = hash(message) % UInt32
    end
    if domain isa Domain && message isa String
        # if domain and message are constant, using a StringHandle
        message = :(init!($(StringHandle(domain, message))))
    else
        message = esc(message)
    end
    # lazily initialize the domain
    domain = :(init!($(esc(domain))))
    color = esc(color)
    category = esc(category)
    payload = esc(payload)
    return domain, message, color, category, payload
end

"""
    NVTX.@mark [message] [domain=...] [color=...] [category=...] [payload=...]

Instruments an instantaneous event.

 - `message` is a string. Default is to use `"file:lineno"``. String
   interpolation is supported, but may incur overhead.
 - `domain` is a [`Domain`](@ref). Default is to use the default domain of the
   current module.
 - `color` is either a `Colorant` from the Colors.jl package, or an `UInt32`
   containing an ARGB32 value. Default is to generate one based on the hash of
   the message.
 - `category`: an integer describing the category of the event. Default is 0.
 - `payload`: an optional integer (`Int32`, `UInt32`, `Int64`, `UInt64`) or
   floating point (`Float32`, `Float64`) value to attach to the event.
"""
macro mark(args...)
    domain, message, color, category, payload = domain_attrs(__module__, __source__, args)
    quote
        _isactive = isactive()
        if _isactive
            mark($domain; message=$message, color=$color, category=$category, payload=$payload)
        end
    end
end

"""
    NVTX.@range [message] [domain=...] [color=...] [category=...] [payload=...] expr

Instruments a range over the `expr`. See [`@mark`](@ref) for the other arguments.
"""
macro range(args...)
    @assert length(args) >= 1
    expr = args[end]
    args = args[1:end-1]
    domain, message, color, category, payload = domain_attrs(__module__, __source__, args)
    quote
        _isactive = isactive()
        if _isactive
            rangeid = range_start($domain; message=$message, color=$color, category=$category, payload=$payload)
        end
        try
            $(esc(expr))
        finally
            if _isactive
                range_end(rangeid)
            end
        end
    end
end
