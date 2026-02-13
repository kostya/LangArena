package benchmark

import "core:fmt"
import "core:strings"
import "core:encoding/base64"

Base64Encode :: struct {
    using base: Benchmark,
    result_val: u32,
    size_val:   i64,
    input_data: []u8,
    encoded_str: string,
}

base64encode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    benc := cast(^Base64Encode)bench

    delete(benc.encoded_str)

    encoded, encode_err := base64.encode(benc.input_data)
    if encode_err != nil {

        benc.encoded_str = ""
    } else {
        benc.encoded_str = encoded
    }
    benc.result_val += u32(len(benc.encoded_str))
}

base64encode_checksum :: proc(bench: ^Benchmark) -> u32 {
    benc := cast(^Base64Encode)bench

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    fmt.sbprintf(&builder, "encode ")

    input_len := len(benc.input_data)
    if input_len > 4 {
        for i in 0..<min(4, input_len) {
            fmt.sbprintf(&builder, "%c", benc.input_data[i])
        }
        fmt.sbprintf(&builder, "...")
    } else {
        for i in 0..<input_len {
            fmt.sbprintf(&builder, "%c", benc.input_data[i])
        }
    }

    fmt.sbprintf(&builder, " to ")

    encoded_len := len(benc.encoded_str)
    if encoded_len > 4 {
        for i in 0..<min(4, encoded_len) {
            fmt.sbprintf(&builder, "%c", benc.encoded_str[i])
        }
        fmt.sbprintf(&builder, "...")
    } else {
        for i in 0..<encoded_len {
            fmt.sbprintf(&builder, "%c", benc.encoded_str[i])
        }
    }

    fmt.sbprintf(&builder, ": %d", benc.result_val)

    return checksum_string(strings.to_string(builder))
}

base64encode_prepare :: proc(bench: ^Benchmark) {
    benc := cast(^Base64Encode)bench
    benc.size_val = config_i64(benc.name, "size")
    benc.result_val = 0

    benc.input_data = make([]u8, int(benc.size_val))
    for i in 0..<len(benc.input_data) {
        benc.input_data[i] = 'a'
    }

    encoded, _ := base64.encode(benc.input_data)
    benc.encoded_str = encoded
}

base64encode_cleanup :: proc(bench: ^Benchmark) {
    benc := cast(^Base64Encode)bench

    delete(benc.input_data)
    delete(benc.encoded_str)
}

create_base64encode :: proc() -> ^Benchmark {
    bench := new(Base64Encode)
    bench.name = "Base64Encode"
    bench.vtable = default_vtable()

    bench.vtable.run = base64encode_run
    bench.vtable.checksum = base64encode_checksum
    bench.vtable.prepare = base64encode_prepare
    bench.vtable.cleanup = base64encode_cleanup

    return cast(^Benchmark)bench
}

Base64Decode :: struct {
    using base: Benchmark,
    result_val:  u32,
    size_val:    i64,
    encoded_str: string,
    decoded_data: []u8,
}

base64decode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bdec := cast(^Base64Decode)bench

    delete(bdec.decoded_data)

    decoded, decode_err := base64.decode(bdec.encoded_str)
    if decode_err != nil {
        bdec.decoded_data = make([]u8, 0)
    } else {
        bdec.decoded_data = decoded
    }
    bdec.result_val += u32(len(bdec.decoded_data))
}

base64decode_checksum :: proc(bench: ^Benchmark) -> u32 {
    bdec := cast(^Base64Decode)bench

    builder := strings.builder_make()
    defer strings.builder_destroy(&builder)

    fmt.sbprintf(&builder, "decode ")

    encoded_len := len(bdec.encoded_str)
    if encoded_len > 4 {
        for i in 0..<min(4, encoded_len) {
            fmt.sbprintf(&builder, "%c", bdec.encoded_str[i])
        }
        fmt.sbprintf(&builder, "...")
    } else {
        for i in 0..<encoded_len {
            fmt.sbprintf(&builder, "%c", bdec.encoded_str[i])
        }
    }

    fmt.sbprintf(&builder, " to ")

    decoded_len := len(bdec.decoded_data)
    if decoded_len > 4 {
        for i in 0..<min(4, decoded_len) {
            fmt.sbprintf(&builder, "%c", bdec.decoded_data[i])
        }
        fmt.sbprintf(&builder, "...")
    } else {
        for i in 0..<decoded_len {
            fmt.sbprintf(&builder, "%c", bdec.decoded_data[i])
        }
    }

    fmt.sbprintf(&builder, ": %d", bdec.result_val)

    return checksum_string(strings.to_string(builder))
}

base64decode_prepare :: proc(bench: ^Benchmark) {
    bdec := cast(^Base64Decode)bench
    bdec.size_val = config_i64(bdec.name, "size")
    bdec.result_val = 0

    input_data := make([]u8, int(bdec.size_val))
    defer delete(input_data)
    for i in 0..<len(input_data) {
        input_data[i] = 'a'
    }

    encoded, _ := base64.encode(input_data)
    bdec.encoded_str = encoded

    decoded, _ := base64.decode(bdec.encoded_str)
    bdec.decoded_data = decoded
}

base64decode_cleanup :: proc(bench: ^Benchmark) {
    bdec := cast(^Base64Decode)bench

    delete(bdec.encoded_str)
    delete(bdec.decoded_data)
}

create_base64decode :: proc() -> ^Benchmark {
    bench := new(Base64Decode)
    bench.name = "Base64Decode"
    bench.vtable = default_vtable()

    bench.vtable.run = base64decode_run
    bench.vtable.checksum = base64decode_checksum
    bench.vtable.prepare = base64decode_prepare
    bench.vtable.cleanup = base64decode_cleanup

    return cast(^Benchmark)bench
}