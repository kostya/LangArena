using Base.Threads

function matgen(n::Int64)
    tmp = 1.0 / n / n
    a = Matrix{Float64}(undef, n, n)

    for i in 1:n
        i0 = i - 1  
        for j in 1:n
            j0 = j - 1  
            a[i, j] = tmp * (i0 - j0) * (i0 + j0)
        end
    end

    return a
end

mutable struct Matmul1T <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Matmul1T()
        n = Helper.config_i64("Matmul1T", "n")
        new(n, UInt32(0))
    end
end

name(b::Matmul1T)::String = "Matmul1T"

function matmul_single_thread(a::Matrix{Float64}, b::Matrix{Float64})
    n = size(a, 1)
    b_t = Matrix{Float64}(undef, n, n)

    for j in 1:n
        for i in 1:n
            b_t[j, i] = b[i, j]
        end
    end

    c = Matrix{Float64}(undef, n, n)

    for i in 1:n
        ai = @view a[i, :]
        ci = @view c[i, :]

        for j in 1:n
            bj = @view b_t[j, :]
            s = 0.0

            for k in 1:n
                s += ai[k] * bj[k]
            end

            ci[j] = s
        end
    end

    return c
end

function run(b::Matmul1T, iteration_id::Int64)
    a = matgen(b.n)
    b_mat = matgen(b.n)
    c = matmul_single_thread(a, b_mat)

    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul1T)::UInt32 = b.result

mutable struct Matmul4T <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Matmul4T()
        n = Helper.config_i64("Matmul4T", "n")
        new(n, UInt32(0))
    end
end

name(b::Matmul4T)::String = "Matmul4T"

function matmul_n_threads(a::Matrix{Float64}, b::Matrix{Float64}, nthreads::Int)
    n = size(a, 1)
    b_t = Matrix{Float64}(undef, n, n)

    for j in 1:n
        for i in 1:n
            b_t[j, i] = b[i, j]
        end
    end

    c = Matrix{Float64}(undef, n, n)

    rows_per_chunk = div(n + nthreads - 1, nthreads)

    tasks = Task[]
    for chunk in 0:nthreads-1
        start_row = chunk * rows_per_chunk + 1
        end_row = min(start_row + rows_per_chunk - 1, n)

        if start_row <= n
            task = Threads.@spawn begin
                for i in start_row:end_row
                    ai = @view a[i, :]
                    ci = @view c[i, :]

                    for j in 1:n
                        bj = @view b_t[j, :]
                        s = 0.0

                        for k in 1:n
                            s += ai[k] * bj[k]
                        end

                        ci[j] = s
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
    a = matgen(b.n)
    b_mat = matgen(b.n)
    c = matmul_n_threads(a, b_mat, 4)

    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul4T)::UInt32 = b.result

mutable struct Matmul8T <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Matmul8T()
        n = Helper.config_i64("Matmul8T", "n")
        new(n, UInt32(0))
    end
end

name(b::Matmul8T)::String = "Matmul8T"

function run(b::Matmul8T, iteration_id::Int64)
    a = matgen(b.n)
    b_mat = matgen(b.n)
    c = matmul_n_threads(a, b_mat, 8)

    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul8T)::UInt32 = b.result

mutable struct Matmul16T <: AbstractBenchmark
    n::Int64
    result::UInt32

    function Matmul16T()
        n = Helper.config_i64("Matmul16T", "n")
        new(n, UInt32(0))
    end
end

name(b::Matmul16T)::String = "Matmul16T"

function run(b::Matmul16T, iteration_id::Int64)
    a = matgen(b.n)
    b_mat = matgen(b.n)
    c = matmul_n_threads(a, b_mat, 16)

    idx = (b.n >> 1) + 1
    b.result += Helper.checksum_f64(c[idx, idx])
end

checksum(b::Matmul16T)::UInt32 = b.result