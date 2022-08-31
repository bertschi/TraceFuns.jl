
using TraceMe

using Test
using Suppressor

fibo(n::Integer) = if n < 2 1 else fibo(n - 1) + fibo(n - 2) end

@testset "Tracing" begin
    res = @suppress begin
        @trace fibo(5) fibo
    end
    @test res == 8
end

@testset "Trace output" begin
    trace = @capture_out begin
        @trace fibo(3) fibo
    end
    
    expected = [
        "0: fibo(3) -- Method fibo(n::Integer)",
        "   1: fibo(2) -- Method fibo(n::Integer)",
        "       2: fibo(1) -- Method fibo(n::Integer)",
        "       2: fibo(1) -> 1",
        "       2: fibo(0) -- Method fibo(n::Integer)",
        "       2: fibo(0) -> 1",
        "   1: fibo(2) -> 2",
        "   1: fibo(1) -- Method fibo(n::Integer)",
        "   1: fibo(1) -> 1",
        "0: fibo(3) -> 3"]

    @test all(map(startswith, split(trace, "\n"), expected))
end
