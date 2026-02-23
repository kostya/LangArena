using Base.Threads

function matgen(n::Int64)
    tmp = 1.0 / n / n
    a = Matrix{Float64}(undef, n, n)

    for i = 1:n
        i0 = i - 1
        for j = 1:n
            j0 = j - 1
            a[i, j] = tmp * (i0 - j0) * (i0 + j0)
        end
    end

    return a
end

mutable struct Matmul1T <: AbstractBenchmark
    n::Int64
    a::Matrix{Float64}
    b::Matrix{Float64}
    result::UInt32

    function Matmul1T()
        n = Helper.config_i64("Matmul::Single", "n")
        a = matgen(n)
        b = matgen(n)
        new(n, a, b, UInt32(0))
    end
end

name(::Matmul1T)::String = "Matmul::Single"

function matmul_single(a::Matrix{Float64}, b::Matrix{Float64})::Matrix{Float64}
    n = size(a, 1)

    b_t = Matrix{Float64}(undef, n, n)
    for j = 1:n, i = 1:n
        b_t[j, i] = b[i, j]
    end

    c = Matrix{Float64}(undef, n, n)
    for i = 1:n
        for j = 1:n
            s = 0.0
            for k = 1:n
                s += a[i, k] * b_t[j, k]
            end
            c[i, j] = s
        end
    end

    return c
end

function run(b::Matmul1T, iteration_id::Int64)
    c = matmul_single(b.a, b.b)
    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul1T)::UInt32 = b.result

mutable struct Matmul4T <: AbstractBenchmark
    n::Int64
    a::Matrix{Float64}
    b::Matrix{Float64}
    result::UInt32

    function Matmul4T()
        n = Helper.config_i64("Matmul::T4", "n")
        a = matgen(n)
        b = matgen(n)
        new(n, a, b, UInt32(0))
    end
end

name(::Matmul4T)::String = "Matmul::T4"

function matmul_parallel(
    a::Matrix{Float64},
    b::Matrix{Float64},
    nthreads::Int,
)::Matrix{Float64}
    n = size(a, 1)

    b_t = Matrix{Float64}(undef, n, n)
    for j = 1:n, i = 1:n
        b_t[j, i] = b[i, j]
    end

    c = Matrix{Float64}(undef, n, n)
    rows_per_chunk = cld(n, nthreads)

    tasks = Task[]
    for chunk = 0:(nthreads-1)
        start_row = chunk * rows_per_chunk + 1
        end_row = min(start_row + rows_per_chunk - 1, n)

        if start_row <= n
            task = Threads.@spawn begin
                for i = start_row:end_row
                    for j = 1:n
                        s = 0.0
                        for k = 1:n
                            s += a[i, k] * b_t[j, k]
                        end
                        c[i, j] = s
                    end
                end
            end
            push!(tasks, task)
        end
    end

    for t in tasks
        wait(t)
    end

    return c
end

function run(b::Matmul4T, iteration_id::Int64)
    c = matmul_parallel(b.a, b.b, 4)
    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul4T)::UInt32 = b.result

mutable struct Matmul8T <: AbstractBenchmark
    n::Int64
    a::Matrix{Float64}
    b::Matrix{Float64}
    result::UInt32

    function Matmul8T()
        n = Helper.config_i64("Matmul::T8", "n")
        a = matgen(n)
        b = matgen(n)
        new(n, a, b, UInt32(0))
    end
end

name(::Matmul8T)::String = "Matmul::T8"

function run(b::Matmul8T, iteration_id::Int64)
    c = matmul_parallel(b.a, b.b, 8)
    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul8T)::UInt32 = b.result

mutable struct Matmul16T <: AbstractBenchmark
    n::Int64
    a::Matrix{Float64}
    b::Matrix{Float64}
    result::UInt32

    function Matmul16T()
        n = Helper.config_i64("Matmul::T16", "n")
        a = matgen(n)
        b = matgen(n)
        new(n, a, b, UInt32(0))
    end
end

name(::Matmul16T)::String = "Matmul::T16"

function run(b::Matmul16T, iteration_id::Int64)
    c = matmul_parallel(b.a, b.b, 16)
    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul16T)::UInt32 = b.result
