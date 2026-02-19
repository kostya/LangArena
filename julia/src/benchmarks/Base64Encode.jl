using Base64

mutable struct Base64Encode <: AbstractBenchmark
    n::Int64
    str::String
    str2::String
    result::UInt32

    function Base64Encode()
        n = Helper.config_i64("Base64Encode", "size")
        new(n, "", "", UInt32(0))
    end
end

name(b::Base64Encode)::String = "Base64Encode"

function prepare(b::Base64Encode)
    b.str = "a" ^ b.n
    b.str2 = base64encode(b.str)
end

function run(b::Base64Encode, iteration_id::Int64)
    b.str2 = base64encode(b.str)
    b.result += UInt32(sizeof(b.str2))
end

function checksum(b::Base64Encode)::UInt32
    str_preview = length(b.str) > 4 ? b.str[1:4] * "..." : b.str
    str2_preview = length(b.str2) > 4 ? b.str2[1:4] * "..." : b.str2
    msg = "encode $(str_preview) to $(str2_preview): $(b.result)"
    return Helper.checksum(msg)
end
