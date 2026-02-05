mutable struct RegexDna <: AbstractBenchmark
    seq::String
    ilen::Int32
    clen::Int32
    io::IOBuffer
    fasta_n::Int64

    function RegexDna()
        fasta_n = Helper.config_i64("RegexDna", "n")
        new("", Int32(0), Int32(0), IOBuffer(), fasta_n)
    end
end

name(b::RegexDna)::String = "RegexDna"

function prepare(b::RegexDna)

    fasta = Fasta()
    fasta.n = b.fasta_n
    run(fasta, 0)

    if isdefined(fasta, :io)
        seekstart(fasta.io)
        res = String(take!(fasta.io))
    elseif isdefined(fasta, :result)
        res = fasta.result
    else
        error("Fasta должен иметь поле io или result")
    end

    b.ilen = Int32(length(res))

    seq_chunks = String[]
    for line in split(res, '\n')
        if !startswith(line, '>')
            push!(seq_chunks, line)
        end
    end

    b.seq = join(seq_chunks)
    b.clen = Int32(sizeof(b.seq))
end

function run(b::RegexDna, iteration_id::Int64)
    io = b.io

    patterns = [
        r"agggtaaa|tttaccct",
        r"[cgt]gggtaaa|tttaccc[acg]",
        r"a[act]ggtaaa|tttacc[agt]t",
        r"ag[act]gtaaa|tttac[agt]ct",
        r"agg[act]taaa|ttta[agt]cct",
        r"aggg[acg]aaa|ttt[cgt]ccct",
        r"agggt[cgt]aa|tt[acg]accct",
        r"agggta[cgt]a|t[acg]taccct",
        r"agggtaa[cgt]|[acg]ttaccct",
    ]

    for regex in patterns
        count = 0
        pos = 1
        while true
            m = match(regex, b.seq, pos)
            if m === nothing
                break
            end
            count += 1
            pos = m.offset + length(m.match)
        end
        write(io, "$(regex.pattern) $count\n")
    end

    replacements = [
        ('B', "(c|g|t)"),
        ('D', "(a|g|t)"),
        ('H', "(a|c|t)"),
        ('K', "(g|t)"),
        ('M', "(a|c)"),
        ('N', "(a|c|g|t)"),
        ('R', "(a|g)"),
        ('S', "(c|t)"),
        ('V', "(a|c|g)"),
        ('W', "(a|t)"),
        ('Y', "(c|t)"),
    ]

    modified_len = 0
    for ch in b.seq
        replaced = false
        for (from_char, to_str) in replacements
            if ch == from_char
                modified_len += length(to_str)
                replaced = true
                break
            end
        end
        if !replaced
            modified_len += 1
        end
    end

    write(io, "\n")
    write(io, "$(b.ilen)\n")
    write(io, "$(b.clen)\n")
    write(io, "$modified_len\n")
end

function checksum(b::RegexDna)::UInt32
    return Helper.checksum(String(take!(b.io)))
end