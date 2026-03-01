function generate_pair_strings(n, m)
    pairs = Vector{Tuple{String,String}}(undef, n)
    chars = collect('a':'j')

    for i = 1:n
        len1 = Helper.next_int(m) + 4
        len2 = Helper.next_int(m) + 4

        str1 = String([chars[Helper.next_int(10)+1] for _ = 1:len1])
        str2 = String([chars[Helper.next_int(10)+1] for _ = 1:len2])

        pairs[i] = (str1, str2)
    end

    return pairs
end

mutable struct Jaro <: AbstractBenchmark
    count::Int64
    size::Int64
    pairs::Vector{Tuple{String,String}}
    result::UInt32

    function Jaro()
        count = Helper.config_i64("Distance::Jaro", "count")
        size = Helper.config_i64("Distance::Jaro", "size")
        new(count, size, Vector{Tuple{String,String}}(), UInt32(0))
    end
end

function name(b::Jaro)::String
    return "Distance::Jaro"
end

function prepare(b::Jaro)
    b.pairs = generate_pair_strings(b.count, b.size)
    b.result = UInt32(0)
end

function jaro(s1::String, s2::String)::Float64
    bytes1 = Vector{UInt8}(s1)
    bytes2 = Vector{UInt8}(s2)

    len1 = length(bytes1)
    len2 = length(bytes2)

    if len1 == 0 || len2 == 0
        return 0.0
    end

    match_dist = max(len1, len2) ÷ 2 - 1
    if match_dist < 0
        match_dist = 0
    end

    s1_matches = falses(len1)
    s2_matches = falses(len2)

    matches = 0
    for i = 1:len1
        start_idx = max(1, i - match_dist)
        end_idx = min(len2, i + match_dist)

        for j = start_idx:end_idx
            if !s2_matches[j] && bytes1[i] == bytes2[j]
                s1_matches[i] = true
                s2_matches[j] = true
                matches += 1
                break
            end
        end
    end

    if matches == 0
        return 0.0
    end

    transpositions = 0
    k = 1
    for i = 1:len1
        if s1_matches[i]
            while k <= len2 && !s2_matches[k]
                k += 1
            end
            if k <= len2
                if bytes1[i] != bytes2[k]
                    transpositions += 1
                end
                k += 1
            end
        end
    end
    transpositions ÷= 2

    m = Float64(matches)
    return (m/len1 + m/len2 + (m - transpositions)/m) / 3.0
end

function run(b::Jaro, iteration_id::Int64)
    for (s1, s2) in b.pairs

        val = jaro(s1, s2) * 1000
        b.result += UInt32(floor(Int, val))
    end
end

function checksum(b::Jaro)::UInt32
    return b.result
end

mutable struct NGram <: AbstractBenchmark
    count::Int64
    size::Int64
    pairs::Vector{Tuple{String,String}}
    result::UInt32
    const N::Int

    function NGram()
        count = Helper.config_i64("Distance::NGram", "count")
        size = Helper.config_i64("Distance::NGram", "size")
        new(count, size, Vector{Tuple{String,String}}(), UInt32(0), 4)
    end
end

function name(b::NGram)::String
    return "Distance::NGram"
end

function prepare(b::NGram)
    b.pairs = generate_pair_strings(b.count, b.size)
    b.result = UInt32(0)
end

function ngram(b::NGram, s1::String, s2::String)::Float64
    if length(s1) < b.N || length(s2) < b.N
        return 0.0
    end

    bytes1 = Vector{UInt8}(s1)
    bytes2 = Vector{UInt8}(s2)

    grams1 = Dict{UInt32,Int32}()
    sizehint!(grams1, length(bytes1))

    for i = 1:(length(bytes1)-b.N+1)
        gram =
            (UInt32(bytes1[i]) << 24) | (UInt32(bytes1[i+1]) << 16) |
            (UInt32(bytes1[i+2]) << 8) | UInt32(bytes1[i+3])

        grams1[gram] = get!(()->Int32(0), grams1, gram) + Int32(1)
    end

    grams2 = Dict{UInt32,Int32}()
    sizehint!(grams2, length(bytes2))
    intersection = 0

    for i = 1:(length(bytes2)-b.N+1)
        gram =
            (UInt32(bytes2[i]) << 24) | (UInt32(bytes2[i+1]) << 16) |
            (UInt32(bytes2[i+2]) << 8) | UInt32(bytes2[i+3])

        grams2[gram] = get!(()->Int32(0), grams2, gram) + Int32(1)

        v = Base.get(grams1, gram, Int32(0))
        if v > 0 && grams2[gram] <= v
            intersection += 1
        end
    end

    total = length(grams1) + length(grams2)
    return total > 0 ? Float64(intersection) / total : 0.0
end

function run(b::NGram, iteration_id::Int64)
    for (s1, s2) in b.pairs
        val = ngram(b, s1, s2) * 1000
        b.result += UInt32(floor(val))
    end
end

function checksum(b::NGram)::UInt32
    return b.result
end
