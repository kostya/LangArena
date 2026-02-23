struct Gene
    c::Char
    prob::Float64
end

const IUB = [
    Gene('a', 0.27),
    Gene('c', 0.39),
    Gene('g', 0.51),
    Gene('t', 0.78),
    Gene('B', 0.8),
    Gene('D', 0.8200000000000001),
    Gene('H', 0.8400000000000001),
    Gene('K', 0.8600000000000001),
    Gene('M', 0.8800000000000001),
    Gene('N', 0.9000000000000001),
    Gene('R', 0.9200000000000002),
    Gene('S', 0.9400000000000002),
    Gene('V', 0.9600000000000002),
    Gene('W', 0.9800000000000002),
    Gene('Y', 1.0000000000000002),
]

const HOMO = [
    Gene('a', 0.302954942668),
    Gene('c', 0.5009432431601),
    Gene('g', 0.6984905497992),
    Gene('t', 1.0),
]

const ALU = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA"

mutable struct Fasta <: AbstractBenchmark
    n::Int64
    io::IOBuffer

    function Fasta()
        n = Helper.config_i64("CLBG::Fasta", "n")
        new(n, IOBuffer())
    end
end

name(b::Fasta)::String = "CLBG::Fasta"

const LINE_LENGTH = 60

const IUB_SORTED = sort(IUB, by = x->x.prob)
const HOMO_SORTED = sort(HOMO, by = x->x.prob)

function select_random(genelist::Vector{Gene})::Char
    r = Helper.next_float()

    for i = 1:length(genelist)
        if r < genelist[i].prob
            return genelist[i].c
        end
    end
    return genelist[end].c
end

function make_random_fasta(
    b::Fasta,
    id::String,
    desc::String,
    genelist::Vector{Gene},
    n_iter::Int,
)
    io = b.io
    write(io, ">$id $desc\n")
    todo = n_iter

    buffer = Vector{UInt8}(undef, LINE_LENGTH)

    while todo > 0
        m = min(todo, LINE_LENGTH)

        for i = 1:m
            buffer[i] = UInt8(select_random(genelist))
        end

        write(io, view(buffer, 1:m))
        write(io, '\n')
        todo -= m
    end
end

function make_repeat_fasta(b::Fasta, id::String, desc::String, s::String, n_iter::Int)
    io = b.io
    write(io, ">$id $desc\n")
    todo = n_iter
    k = 1
    kn = length(s)

    while todo > 0
        m = min(todo, LINE_LENGTH)

        remaining = kn - k + 1
        if m >= remaining

            write(io, view(s, k:kn))
            m -= remaining
            k = 1

            full_repeats = m ÷ kn
            if full_repeats > 0
                for _ = 1:full_repeats
                    write(io, s)
                end
                m -= full_repeats * kn
            end

            if m > 0
                write(io, view(s, 1:m))
                k = m + 1
            end
        else
            write(io, view(s, k:(k+m-1)))
            k += m
        end

        write(io, '\n')
        todo -= LINE_LENGTH
    end
end

function run(b::Fasta, iteration_id::Int64)
    n_int = Int(b.n)

    make_repeat_fasta(b, "ONE", "Homo sapiens alu", ALU, n_int * 2)
    make_random_fasta(b, "TWO", "IUB ambiguity codes", IUB_SORTED, n_int * 3)
    make_random_fasta(b, "THREE", "Homo sapiens frequency", HOMO_SORTED, n_int * 5)
end

function checksum(b::Fasta)::UInt32
    result_str = String(take!(b.io))
    return Helper.checksum(result_str)
end
