using ..BenchmarkFramework

abstract type AbstractBufferHashBenchmark <: AbstractBenchmark end

mutable struct BufferHashBenchmark <: AbstractBufferHashBenchmark
    size::Int64
    data::Vector{UInt8}
    result::UInt32

    function BufferHashBenchmark()
        size_val = Helper.config_i64("BufferHashBenchmark", "size")
        new(size_val, Vector{UInt8}(undef, size_val), UInt32(0))
    end
end

name(b::BufferHashBenchmark)::String = "BufferHashBenchmark"

function prepare(b::BufferHashBenchmark)
    for i in 1:length(b.data)
        b.data[i] = UInt8(Helper.next_int(256))
    end
end

function test(b::BufferHashBenchmark)::UInt32

    error("Abstract method 'test' not implemented")
end

function run(b::BufferHashBenchmark, iteration_id::Int64)
    hash_val = test(b)
    b.result = (b.result + hash_val) & 0xffffffff
end

function checksum(b::BufferHashBenchmark)::UInt32
    return b.result
end

mutable struct BufferHashSHA256 <: AbstractBufferHashBenchmark
    size::Int64
    data::Vector{UInt8}
    result::UInt32

    function BufferHashSHA256()
        size_val = Helper.config_i64("BufferHashSHA256", "size")
        new(size_val, Vector{UInt8}(undef, size_val), UInt32(0))
    end
end

name(b::BufferHashSHA256)::String = "BufferHashSHA256"

function prepare(b::BufferHashSHA256)
    for i in 1:length(b.data)
        b.data[i] = UInt8(Helper.next_int(256))
    end
end

module SimpleSHA256
    const INITIAL_HASHES = UInt32[
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]

    function digest(data::Vector{UInt8})::Vector{UInt8}
        hashes = copy(INITIAL_HASHES)

        for (i, byte_val) in enumerate(data)
            byte = UInt32(byte_val)
            hash_idx = (i - 1) % 8 + 1  

            hash = hashes[hash_idx]
            hash = ((hash << 5) + hash) + byte

            hash = (hash + (hash << 10)) ⊻ (hash >> 6)

            hashes[hash_idx] = hash
        end

        result = Vector{UInt8}(undef, 32)
        for i in 1:8
            hash = hashes[i]

            result[(i-1)*4 + 1] = UInt8((hash >> 24) & 0xff)  
            result[(i-1)*4 + 2] = UInt8((hash >> 16) & 0xff)
            result[(i-1)*4 + 3] = UInt8((hash >> 8) & 0xff)
            result[(i-1)*4 + 4] = UInt8(hash & 0xff)          
        end

        return result
    end
end

function test(b::BufferHashSHA256)::UInt32
    bytes = SimpleSHA256.digest(b.data)

    return reinterpret(UInt32, bytes[1:4])[1]  

    b0 = UInt32(bytes[1])  
    b1 = UInt32(bytes[2])
    b2 = UInt32(bytes[3])
    b3 = UInt32(bytes[4])  

    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
end

function run(b::BufferHashSHA256, iteration_id::Int64)
    hash_val = test(b)
    b.result = (b.result + hash_val) & 0xffffffff
end

function checksum(b::BufferHashSHA256)::UInt32
    return b.result
end

mutable struct BufferHashCRC32 <: AbstractBufferHashBenchmark
    size::Int64
    data::Vector{UInt8}
    result::UInt32

    function BufferHashCRC32()
        size_val = Helper.config_i64("BufferHashCRC32", "size")
        new(size_val, Vector{UInt8}(undef, size_val), UInt32(0))
    end
end

name(b::BufferHashCRC32)::String = "BufferHashCRC32"

function prepare(b::BufferHashCRC32)
    for i in 1:length(b.data)
        b.data[i] = UInt8(Helper.next_int(256))
    end
end

function crc32_compute(data::Vector{UInt8})::UInt32
    crc = 0xffffffff

    for byte in data
        crc = crc ⊻ UInt32(byte)
        for _ in 1:8
            if (crc & 1) != 0
                crc = (crc >> 1) ⊻ 0xedb88320
            else
                crc = crc >> 1
            end
        end
    end

    return crc ⊻ 0xffffffff
end

function test(b::BufferHashCRC32)::UInt32
    return crc32_compute(b.data)
end

function run(b::BufferHashCRC32, iteration_id::Int64)
    hash_val = test(b)
    b.result = (b.result + hash_val) & 0xffffffff
end

function checksum(b::BufferHashCRC32)::UInt32
    return b.result
end