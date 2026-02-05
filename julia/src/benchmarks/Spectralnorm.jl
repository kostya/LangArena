mutable struct Spectralnorm <: AbstractBenchmark
    size::Int64
    u::Vector{Float64}
    v::Vector{Float64}
    result::UInt32

    function Spectralnorm()
        size_val = Helper.config_i64("Spectralnorm", "size")
        u = fill(1.0, size_val)
        v = fill(1.0, size_val)
        new(size_val, u, v, UInt32(0))
    end
end

name(b::Spectralnorm)::String = "Spectralnorm"

@inline function eval_A(i::Int64, j::Int64)::Float64

    ij = Float64(i + j)
    return 1.0 / ((ij * (ij + 1.0)) / 2.0 + Float64(i) + 1.0)
end

function eval_A_times_u(u::Vector{Float64})::Vector{Float64}
    n = length(u)
    v = Vector{Float64}(undef, n)

    @inbounds for i in 1:n
        s = 0.0
        @simd for j in 1:n
            s += eval_A(i-1, j-1) * u[j]  
        end
        v[i] = s
    end

    return v
end

function eval_At_times_u(u::Vector{Float64})::Vector{Float64}
    n = length(u)
    v = Vector{Float64}(undef, n)

    @inbounds for i in 1:n
        s = 0.0
        @simd for j in 1:n
            s += eval_A(j-1, i-1) * u[j]  
        end
        v[i] = s
    end

    return v
end

function eval_AtA_times_u(u::Vector{Float64})::Vector{Float64}

    Au = eval_A_times_u(u)
    return eval_At_times_u(Au)
end

function run(b::Spectralnorm, iteration_id::Int64)
    b.v = eval_AtA_times_u(b.u)
    b.u = eval_AtA_times_u(b.v)
end

function checksum(b::Spectralnorm)::UInt32
    vBv = vv = 0.0

    @inbounds for i in 1:b.size
        vBv += b.u[i] * b.v[i]
        vv += b.v[i] * b.v[i]
    end

    result = sqrt(vBv / vv)
    return Helper.checksum_f64(result)
end