package benchmark

import "core:fmt"
import "core:hash"

BufferHash :: struct {
    using base: Benchmark,
    data: []u8,
    size_val: int,
    result_val: u32,

    test_proc: proc(bench: ^BufferHash) -> u32,
}

bufferhash_test_wrapper :: proc(bench: ^Benchmark) -> u32 {
    bh := cast(^BufferHash)bench
    if bh.test_proc != nil {
        return bh.test_proc(bh)
    }
    return 0
}

bufferhash_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bh := cast(^BufferHash)bench

    bh.result_val += bufferhash_test_wrapper(bench)
}

bufferhash_checksum :: proc(bench: ^Benchmark) -> u32 {
    bh := cast(^BufferHash)bench
    return bh.result_val
}

bufferhash_prepare :: proc(bench: ^Benchmark) {
    bh := cast(^BufferHash)bench

    if bh.size_val == 0 {
        bh.size_val = int(config_i64(bh.name, "size"))
        bh.data = make([]u8, bh.size_val)

        for i in 0..<bh.size_val {
            bh.data[i] = u8(next_int(256))
        }
    }
}

bufferhash_cleanup :: proc(bench: ^Benchmark) {
    bh := cast(^BufferHash)bench
    if bh.data != nil {
        delete(bh.data)
    }
}

BufferHashSHA256 :: struct {
    base: BufferHash,
}

simple_sha256 :: proc(data: []u8) -> [32]u8 {

    hashes: [8]u32 = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }

    for i in 0..<len(data) {
        hash_idx := i % 8
        hash := &hashes[hash_idx]

        v := hash^
        v2 := ((v << 5) + v) + u32(data[i])
        hash^ = (v2 + (v2 << 10)) ~ (v2 >> 6)
    }

    result: [32]u8
    for i in 0..<8 {
        result[i * 4] = u8(hashes[i] >> 24)
        result[i * 4 + 1] = u8(hashes[i] >> 16)
        result[i * 4 + 2] = u8(hashes[i] >> 8)
        result[i * 4 + 3] = u8(hashes[i])
    }

    return result
}

sha256_test :: proc(bh: ^BufferHash) -> u32 {
    hash_result := simple_sha256(bh.data)

    result: u32
    result_ptr := cast(^u32)&hash_result[0]
    return result_ptr^
}

create_buffhashsha256 :: proc() -> ^Benchmark {
    bench := new(BufferHashSHA256)

    bench.base.name = "BufferHashSHA256"
    bench.base.vtable = default_vtable()

    bench.base.vtable.run = bufferhash_run
    bench.base.vtable.checksum = bufferhash_checksum
    bench.base.vtable.prepare = bufferhash_prepare
    bench.base.vtable.cleanup = bufferhash_cleanup

    bench.base.test_proc = sha256_test

    return cast(^Benchmark)bench
}

BufferHashCRC32 :: struct {
    base: BufferHash,
}

crc32_simple :: proc(data: []u8) -> u32 {
    crc: u32 = 0xFFFFFFFF

    for byte in data {
        crc = crc ~ u32(byte)

        for j in 0..<8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ~ 0xEDB88320
            } else {
                crc = crc >> 1
            }
        }
    }

    return crc ~ 0xFFFFFFFF
}

crc32_test :: proc(bh: ^BufferHash) -> u32 {
    return crc32_simple(bh.data)
}

create_buffhashcrc32 :: proc() -> ^Benchmark {
    bench := new(BufferHashCRC32)

    bench.base.name = "BufferHashCRC32"
    bench.base.vtable = default_vtable()

    bench.base.vtable.run = bufferhash_run
    bench.base.vtable.checksum = bufferhash_checksum
    bench.base.vtable.prepare = bufferhash_prepare
    bench.base.vtable.cleanup = bufferhash_cleanup

    bench.base.test_proc = crc32_test

    return cast(^Benchmark)bench
}