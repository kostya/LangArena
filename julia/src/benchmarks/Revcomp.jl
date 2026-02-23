mutable struct Revcomp <: AbstractBenchmark
    input::String
    io::IOBuffer
    checksum_val::UInt32
    fasta_n::Int64

    function Revcomp()
        fasta_n = Helper.config_i64("CLBG::Revcomp", "n")
        new("", IOBuffer(), UInt32(0), fasta_n)
    end
end

name(b::Revcomp)::String = "CLBG::Revcomp"

const COMPLEMENT_LOOKUP = let
    table = Vector{UInt8}(undef, 256)
    fill!(table, 0x00)

    for i = 0:255
        table[i+1] = UInt8(i)
    end

    from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
    to = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"

    for i = 1:length(from)
        byte = UInt8(from[i])
        table[byte+1] = UInt8(to[i])
    end

    table
end

function prepare(b::Revcomp)

    fasta = Fasta()
    fasta.n = b.fasta_n
    run(fasta, 0)

    if isdefined(fasta, :io)
        seekstart(fasta.io)
        input = String(take!(fasta.io))
    elseif isdefined(fasta, :result)
        input = fasta.result
    else
        error("Fasta должен иметь поле io или result")
    end

    result = ""

    for line in split(input, '\n')
        if startswith(line, '>')
            result *= "\n---\n"
        else
            result *= line
        end
    end

    if !isempty(result) && result[1] == '\n'
        result = result[2:end]
    end

    b.input = result
end

function revcomp(b::Revcomp, seq::String)::Vector{UInt8}
    bytes = Vector{UInt8}(seq)
    bytesize = length(bytes)

    reverse!(bytes)

    for i = 1:bytesize
        bytes[i] = COMPLEMENT_LOOKUP[bytes[i]+1]
    end

    result = UInt8[]
    chunk_size = 60

    for start_idx = 1:chunk_size:bytesize
        end_idx = min(start_idx + chunk_size - 1, bytesize)

        append!(result, bytes[start_idx:end_idx])
        push!(result, UInt8('\n'))
    end

    push!(result, UInt8('\n'))

    return result
end

function run(b::Revcomp, iteration_id::Int64)
    result_bytes = revcomp(b, b.input)
    b.checksum_val += Helper.checksum(result_bytes)
end

function checksum(b::Revcomp)::UInt32
    return b.checksum_val
end
