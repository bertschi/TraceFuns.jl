module TraceFuns

export @trace
export tracing

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
        prefix = ctx.metadata.show_call ? "$(callstr(fun, args)) -- " : ""
        println(indent(ctx.metadata.indent, "$prefix$methstr"))
    end
    if Cassette.canrecurse(ctx, fun, args...)
        newctx = Cassette.similarcontext(
            ctx,
            metadata = (
                funs = ctx.metadata.funs,
                indent = ctx.metadata.indent + 1,
                show_call = ctx.metadata.show_call,
                show_return = ctx.metadata.show_return,
            )
        )
        # Note: Work around potential Cassette bugs ...
        try
            res = Cassette.recurse(newctx, fun, args...)
        catch
            res = Cassette.fallback(ctx, fun, args...)
        end
    else
        res = Cassette.fallback(ctx, fun, args...)
    end
    if needprint && ctx.metadata.indent ≥ 0 && ctx.metadata.show_return
        println(indent(ctx.metadata.indent, "$(callstr(fun, args)) -> $res"))
    end
    res
end

"""
    @trace expr [funs...] [show_call = true, show_return = true]

Trace all calls of the listed `funs` during evaluation of `expr`.
If `funs` includes the symbol `:all` all function calls are traced.
If `funs` includes one or more modules, all functions from the corresponding modules are traced. 

# Options
- `show_call`: whether to print the function call (default: `true`)
- `show_return`: whether to print the function return value (default: `true`)
Setting one or both of these to `false` can be useful to reduce the output.

# Examples
```julia-repl
julia> @trace 1 + 2 Base.:+
0: +(1, 2) -- Method +(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} @ Base int.jl:87 of +
0: +(1, 2) -> 3
3
```

Be careful using `:all` as the output may be long ...
```julia-repl
julia> @trace 1 * 2.0 :all
0: *(1, 2.0) -- Method *(x::Number, y::Number) @ Base promotion.jl:411 of *
   1: promote(1, 2.0) -- Method promote(x, y) @ Base promotion.jl:379 of promote
      ... long output clipped ...
   1: promote(1, 2.0) -> (1.0, 2.0)
   1: *(1.0, 2.0) -- Method *(x::T, y::T) where T<:Union{Float16, Float32, Float64} @ Base float.jl:410 of *
       2: mul_float(1.0, 2.0) -- Method IntrinsicFunction(...) @ Core none:0 of mul_float
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
0: fibo(3) -- Method fibo(n::Integer) @ Main REPL[3]:1 of fibo
   1: fibo(2) -- Method fibo(n::Integer) @ Main REPL[3]:1 of fibo
       2: fibo(1) -- Method fibo(n::Integer) @ Main REPL[3]:1 of fibo
       2: fibo(1) -> 1
       2: fibo(0) -- Method fibo(n::Integer) @ Main REPL[3]:1 of fibo
       2: fibo(0) -> 1
   1: fibo(2) -> 2
   1: fibo(1) -- Method fibo(n::Integer) @ Main REPL[3]:1 of fibo
   1: fibo(1) -> 1
0: fibo(3) -> 3
3
```

See also [`tracing`](@ref) for the functional interface.
"""
macro trace(expr, args...)
    funs = []
    kwargs = Pair{Symbol,Bool}[]
    for el in args
        if Meta.isexpr(el, :(=))
            push!(kwargs, Pair(el.args...))
        else
            push!(funs, el)
        end
    end
    expresc = esc(expr)
    funsesc = esc.(funs)
    :(tracing(() -> $expresc, $(funsesc...); $kwargs...))
end

"""
    tracing(funs...; show_call = true, show_return = true) do
        expr
    end

Trace all calls of the listed `funs` during evaluation of `expr`.

# Keyword arguments
- `show_call`: whether to print the function call (default: `true`)
- `show_return`: whether to print the function return value (default: `true`)
Setting one or both of these to `false` can be useful to reduce the output.

# Examples
```julia-repl
julia> fac(n) = if n < 1; 1 else n * fac(n - 1) end
fac (generic function with 1 method)

julia> tracing(Base, fac) do
           fac(2)
       end
0: fac(2) -- Method fac(n) @ Main REPL[25]:1 of fac
   1: <(2, 1) -- Method <(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8} @ Base int.jl:83 of <
   1: <(2, 1) -> false
   1: -(2, 1) -- Method -(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} @ Base int.jl:86 of -
   1: -(2, 1) -> 1
   1: fac(1) -- Method fac(n) @ Main REPL[25]:1 of fac
       2: <(1, 1) -- Method <(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8} @ Base int.jl:83 of <
       2: <(1, 1) -> false
       2: -(1, 1) -- Method -(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} @ Base int.jl:86 of -
       2: -(1, 1) -> 0
       2: fac(0) -- Method fac(n) @ Main REPL[25]:1 of fac
           3: <(0, 1) -- Method <(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8} @ Base int.jl:83 of <
           3: <(0, 1) -> true
       2: fac(0) -> 1
       2: *(1, 1) -- Method *(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} @ Base int.jl:88 of *
       2: *(1, 1) -> 1
   1: fac(1) -> 1
   1: *(2, 1) -- Method *(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} @ Base int.jl:88 of *
   1: *(2, 1) -> 2
0: fac(2) -> 2
2
```

See [`@trace`](@ref) for further details.
"""
function tracing(thunk, funs...; show_call::Bool = true, show_return::Bool = true)
    ctx = TraceCtx(metadata = (funs = [funs...], indent = -1, show_call, show_return))
    Cassette.overdub(ctx, thunk)
end

end # module
