mutable struct Base64Decode <: AbstractBenchmark
    n::Int64
    str2::String
    bytes::Vector{UInt8}
    result::UInt32

    function Base64Decode()
        n = Helper.config_i64("Base64Decode", "size")
        new(n, "", [], UInt32(0))
    end
end

name(b::Base64Decode)::String = "Base64Decode"

function prepare(b::Base64Decode)
    str = "a" ^ b.n
    b.str2 = base64encode(str)
    b.bytes = base64decode(b.str2)
end

function run(b::Base64Decode, iteration_id::Int64)
    b.bytes = base64decode(b.str2)
    b.result += UInt32(sizeof(b.bytes))
end

function checksum(b::Base64Decode)::UInt32
    str3 = String(b.bytes[1:5])
    str2_preview = length(b.str2) > 4 ? b.str2[1:4] * "..." : b.str2
    str3_preview = length(str3) > 4 ? str3[1:4] * "..." : str3
    msg = "decode $(str2_preview) to $(str3_preview): $(b.result)"
    return Helper.checksum(msg)
end
