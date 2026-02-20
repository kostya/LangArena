mutable struct Pidigits <: AbstractBenchmark
    nn::Int32
    io::IOBuffer

    function Pidigits()
        nn = Int32(Helper.config_i64("Pidigits", "amount"))
        new(nn, IOBuffer())
    end
end

name(b::Pidigits)::String = "Pidigits"

function run(b::Pidigits, iteration_id::Int64)
    i = Int32(0)
    k = Int32(0)

    ns = BigInt(0)
    a = BigInt(0)
    t = BigInt(0)
    u = BigInt(0)
    n = BigInt(1)
    d = BigInt(1)

    k1 = Int32(1)

    while true
        k += 1
        t = n * 2
        n = n * k
        k1 += 2
        a = (a + t) * k1
        d = d * k1
        if a >= n
            temp = n * 3 + a
            q = div(temp, d)
            u = rem(temp, d)
            u = u + n
            if d > u
                ns = ns * 10 + q
                i += 1
                if i % 10 == 0
                    ns_str = string(ns)
                    if length(ns_str) < 10
                        ns_str = "0"^(10 - length(ns_str)) * ns_str
                    end
                    write(b.io, "$(ns_str)\t:$(i)\n")
                    ns = BigInt(0)
                end

                if i >= b.nn
                    break
                end

                a = (a - (d * q)) * 10
                n = n * 10
            end
        end
    end
end

function checksum(b::Pidigits)::UInt32
    result_str = String(take!(b.io))
    return Helper.checksum(result_str)
end
