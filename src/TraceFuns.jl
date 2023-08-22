module TraceFuns

export @trace

using Cassette

Cassette.@context TraceCtx

const _indent = 4

function indent(i::Int, s::String)
    join(fill("", _indent * i), " ") * "$i: " * s
end

function callstr(fun, args)
    fargs = join(args, ", ")
    "$fun($fargs)"
end

match(meth, fun::Function) = meth.name == nameof(fun)
match(meth, fun::Symbol) = fun == :all
match(meth, fun::Module) = meth.module == fun

function Cassette.overdub(ctx::TraceCtx, fun::Function, args...)
    meth = which(fun, Base.typesof(args...))
    needprint = any(match(meth, fun) for fun in ctx.metadata.funs)
    if needprint && ctx.metadata.indent ≥ 0
        methstr = "Method $meth of $fun"
        println(indent(ctx.metadata.indent, "$(callstr(fun, args)) -- $methstr"))
    end
    if Cassette.canrecurse(ctx, fun, args...)
        newctx = Cassette.similarcontext(ctx, metadata = (funs = ctx.metadata.funs, indent = ctx.metadata.indent + 1))
        # Note: Work around potential Cassette bugs ...
        try
            res = Cassette.recurse(newctx, fun, args...)
        catch
            res = Cassette.fallback(ctx, fun, args...)
        end
    else
        res = Cassette.fallback(ctx, fun, args...)
    end
    if needprint && ctx.metadata.indent ≥ 0
        println(indent(ctx.metadata.indent, "$(callstr(fun, args)) -> $res"))
    end
    res
end

"""
    @trace expr [funs...]

Trace all calls of the listed `funs` during evaluation of `expr`.
If `funs` includes the symbol `:all` all function calls are traced.

# Examples
```julia-repl
julia> @trace 1 + 2 Base.:+
0: +(1, 2) -- Method +(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} in Base at int.jl:87
0: +(1, 2) -> 3
3
```

Be careful using `:all` as the output may be long ...
```julia-repl
julia> @trace 1 * 2.0 :all
0: *(1, 2.0) -- Method *(x::Number, y::Number) in Base at promotion.jl:380
   1: promote(1, 2.0) -- Method promote(x, y) in Base at promotion.jl:348
      ... long output clipped ...
   1: promote(1, 2.0) -> (1.0, 2.0)
   1: *(1.0, 2.0) -- Method *(x::Float64, y::Float64) in Base at float.jl:405
       2: mul_float(1.0, 2.0) -- Primitive mul_float
       2: mul_float(1.0, 2.0) -> 2.0
   1: *(1.0, 2.0) -> 2.0
0: *(1, 2.0) -> 2.0
2.0
```

Tracing nicely illustrates recursive functions
```julia-repl
julia> fibo(n::Integer) = if n < 2 1 else fibo(n-1) + fibo(n-2) end
fibo (generic function with 1 method)

julia> @trace fibo(3) fibo
0: fibo(3) -- Method fibo(n::Integer) in Main at REPL[6]:1
   1: fibo(2) -- Method fibo(n::Integer) in Main at REPL[6]:1
       2: fibo(1) -- Method fibo(n::Integer) in Main at REPL[6]:1
       2: fibo(1) -> 1
       2: fibo(0) -- Method fibo(n::Integer) in Main at REPL[6]:1
       2: fibo(0) -> 1
   1: fibo(2) -> 2
   1: fibo(1) -- Method fibo(n::Integer) in Main at REPL[6]:1
   1: fibo(1) -> 1
0: fibo(3) -> 3
3
```
"""
macro trace(expr, funs...)
    expresc = esc(expr)
    funsesc = esc.(funs)
    :(Cassette.overdub(TraceCtx(metadata = (funs = [$(funsesc...)], indent = -1)), () -> $expresc))
end
    
end # module
