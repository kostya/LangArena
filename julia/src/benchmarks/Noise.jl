using StaticArrays

mutable struct Noise <: AbstractBenchmark
    size::Int64
    result::UInt32
    rgradients::Vector{SVector{2,Float64}}
    permutations::Vector{Int32}

    function Noise()
        size_val = Helper.config_i64("Noise", "size")

        rgradients = Vector{SVector{2,Float64}}(undef, size_val)
        for i = 1:size_val
            v = Helper.next_float() * 2π
            rgradients[i] = SVector(cos(v), sin(v))
        end

        permutations = collect(Int32(0):Int32(size_val-1))
        for _ = 1:size_val
            a = Helper.next_int(Int32(size_val))
            b = Helper.next_int(Int32(size_val))
            permutations[a+1], permutations[b+1] = permutations[b+1], permutations[a+1]
        end

        new(size_val, UInt32(0), rgradients, permutations)
    end
end

name(b::Noise)::String = "Noise"

@inline @fastmath function lerp(a::Float64, b::Float64, v::Float64)::Float64
    return a + v * (b - a)
end

@inline @fastmath function smooth(v::Float64)::Float64
    v2 = v * v
    return v2 * (3.0 - 2.0 * v)
end

@inline function get_gradient(b::Noise, x::Int32, y::Int32)::SVector{2,Float64}

    idx = b.permutations[(x&(b.size-1))+1] + b.permutations[(y&(b.size-1))+1]
    return b.rgradients[(idx&(b.size-1))+1]
end

@inline @fastmath function get(b::Noise, x::Float64, y::Float64)::Float64
    x0f = floor(x)
    y0f = floor(y)
    x0 = Int32(x0f)
    y0 = Int32(y0f)

    size_mask = b.size - 1

    px0 = (x0 & size_mask) + 1
    px1 = ((x0 + Int32(1)) & size_mask) + 1
    py0 = (y0 & size_mask) + 1
    py1 = ((y0 + Int32(1)) & size_mask) + 1

    perm = b.permutations
    grad = b.rgradients

    g00 = @inbounds grad[(perm[px0]+perm[py0])&size_mask+1]
    g10 = @inbounds grad[(perm[px1]+perm[py0])&size_mask+1]
    g01 = @inbounds grad[(perm[px0]+perm[py1])&size_mask+1]
    g11 = @inbounds grad[(perm[px1]+perm[py1])&size_mask+1]

    dx = x - x0f
    dy = y - y0f
    dx1 = dx - 1.0
    dy1 = dy - 1.0

    v00 = muladd(g00[1], dx, g00[2] * dy)
    v10 = muladd(g10[1], dx1, g10[2] * dy)
    v01 = muladd(g01[1], dx, g01[2] * dy1)
    v11 = muladd(g11[1], dx1, g11[2] * dy1)

    fx = smooth(dx)
    fy = smooth(dy)

    vx0 = lerp(v00, v10, fx)
    vx1 = lerp(v01, v11, fx)

    return lerp(vx0, vx1, fy)
end

const SYM = [' ', '░', '▒', '▓', '█', '█']

function run(b::Noise, iteration_id::Int64)
    total = UInt32(0)
    size_val = b.size
    y_step = 0.1
    y_start = iteration_id * 12.8

    @inbounds for y = 0:(size_val-1)
        fy = y * y_step + y_start
        @simd for x = 0:(size_val-1)
            fx = x * y_step

            v = (get(b, fx, fy) + 1.0) * 0.5

            idx_f = v * 5.0
            if idx_f >= 5.0
                total += UInt32(SYM[6])
            elseif idx_f <= 0.0
                total += UInt32(SYM[1])
            else
                idx = trunc(Int, idx_f)
                total += UInt32(SYM[idx+1])
            end
        end
    end

    b.result = (b.result + total) & 0xffffffff
end

checksum(b::Noise)::UInt32 = b.result
