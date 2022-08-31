# TraceMe.jl

The `trace` facility of Common Lisp has always been my favourite tool
for debugging or interactively exploring a code base. Yet, it seems to
be missing in almost any other language. Fortunately, the overdub
mechanism of [Cassette.jl](https://github.com/JuliaLabs/Cassette.jl)
allows method tracing for Julia rather easily and here it is ...

```julia
help?> @trace
  @trace expr [funs...]

  Trace all calls of the listed funs during evaluation of expr. If funs includes the symbol :all all function calls are traced.

  Examples
  ≡≡≡≡≡≡≡≡≡≡

  julia> @trace 1 + 2 Base.:+
  0: +(1, 2) -- Method +(x::T, y::T) where T<:Union{Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64, UInt8} in Base at int.jl:87
  0: +(1, 2) -> 3
  3

  Be careful using :all as the output may be long ...
          
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

  Tracing nicely illustrates recursive functions
      
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

## Known issues

* Tracing functions with keyword arguments is currently tricky, i.e.,
  `@trace reduce(+, 1:2; init=0) reduce` will not show any trace
  output and `@trace reduce(+, 1:2; init=0)
  Base.var"#reduce##kw".instance` is needed instead to see the
  corresponding calls.
