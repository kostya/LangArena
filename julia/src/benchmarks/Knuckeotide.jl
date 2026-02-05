mutable struct Knuckeotide <: AbstractBenchmark
    seq::String
    result::String

    function Knuckeotide()
        new("", "")
    end
end

name(b::Knuckeotide)::String = "Knuckeotide"

function frequency(seq::String, len::Int)::Tuple{Int, Dict{String, Int}}
    n = length(seq) - len + 1
    table = Dict{String, Int}()

    for i in 1:n
        sub = seq[i:i+len-1]
        table[sub] = Base.get(table, sub, 0) + 1  
    end

    return (n, table)
end

function find_seq(b::Knuckeotide, seq::String, s::String)
    len_s = length(s)
    n, table = frequency(seq, len_s)
    s_lower = lowercase(s)
    count = Base.get(table, s_lower, 0)  

    s_upper = uppercase(s)
    b.result *= "$count\t$s_upper\n"
end

function sort_by_freq(b::Knuckeotide, seq::String, len::Int)  
    n, table = frequency(seq, len)

    pairs = collect(table)
    sort!(pairs, by = x -> (-x[2], x[1]))

    for (key, value) in pairs
        percent = (value * 100.0) / n
        key_upper = uppercase(key)
        b.result *= "$key_upper $(@sprintf("%.3f", percent))\n"
    end
    b.result *= "\n"
end

function prepare(b::Knuckeotide)

    fasta = Fasta()
    fasta.n = Helper.config_i64("Knuckeotide", "n")

    run(fasta, Int64(0))

    fasta_result = String(take!(fasta.io))
    lines = split(fasta_result, '\n')
    three = false
    seq_parts = String[]

    for line in lines
        if startswith(line, ">THREE")
            three = true
            continue
        end
        if three && !startswith(line, ">") && !isempty(line)
            push!(seq_parts, line)
        end
    end

    b.seq = join(seq_parts)
end

function run(b::Knuckeotide, iteration_id::Int64)
    for i in 1:2
        sort_by_freq(b, b.seq, i)
    end

    searches = ["ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"]
    for s in searches
        find_seq(b, b.seq, s)
    end
end

checksum(b::Knuckeotide)::UInt32 = Helper.checksum(b.result)