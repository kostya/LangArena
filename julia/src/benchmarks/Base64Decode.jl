mutable struct Base64Decode <: AbstractBenchmark
    n::Int64
    str2::String  
    str3::String  
    result::UInt32

    function Base64Decode()
        n = Helper.config_i64("Base64Decode", "size")
        new(n, "", "", UInt32(0))
    end
end

name(b::Base64Decode)::String = "Base64Decode"

function prepare(b::Base64Decode)
    str = "a" ^ b.n
    b.str2 = base64encode(str)
    b.str3 = String(base64decode(b.str2))
end

function run(b::Base64Decode, iteration_id::Int64)
    decoded = base64decode(b.str2)
    b.str3 = String(decoded)
    b.result += UInt32(sizeof(b.str3))
end

function checksum(b::Base64Decode)::UInt32
    str2_preview = length(b.str2) > 4 ? b.str2[1:4] * "..." : b.str2
    str3_preview = length(b.str3) > 4 ? b.str3[1:4] * "..." : b.str3
    msg = "decode $(str2_preview) to $(str3_preview): $(b.result)"
    return Helper.checksum(msg)
end