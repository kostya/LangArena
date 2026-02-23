package benchmark

import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
import "core:slice/heap"
import "core:sort"
import "core:strings"

generate_test_data :: proc(data_size: i64) -> []u8 {
    pattern := "ABRACADABRA"
    data := make([]u8, int(data_size))
    for i in 0..<int(data_size) {
        data[i] = pattern[i % len(pattern)]
    }
    return data
}

BWTResult :: struct {
    transformed: []u8,
    original_idx: int,
}

bwt_transform :: proc(input: []u8) -> BWTResult {
    n := len(input)
    if n == 0 {
        return BWTResult{transformed = make([]u8, 0), original_idx = 0}
    }

    sa := make([]int, n)
    defer delete(sa)
    for i in 0..<n {
        sa[i] = i
    }

    buckets := make([][dynamic]int, 256)
    defer {
        for &b in buckets {
            delete(b)
        }
        delete(buckets)
    }

    for idx in sa {
        append(&buckets[input[idx]], idx)
    }

    pos := 0
    for &b in buckets {
        for idx in b {
            sa[pos] = idx
            pos += 1
        }
    }

    if n > 1 {
        rank := make([]int, n)
        defer delete(rank)

        current_rank := 0
        prev_char := input[sa[0]]

        for i in 0..<n {
            idx := sa[i]
            curr_char := input[idx]
            if curr_char != prev_char {
                current_rank += 1
                prev_char = curr_char
            }
            rank[idx] = current_rank
        }

        k := 1
        for k < n {
            sortable := make([]struct{index, rank1, rank2: int}, n)
            defer delete(sortable)

            for i in 0..<n {
                suffix_idx := sa[i]
                sortable[i].index = suffix_idx
                sortable[i].rank1 = rank[suffix_idx]
                sortable[i].rank2 = rank[(suffix_idx + k) % n]
            }

            sort.quick_sort_proc(sortable, proc(a, b: struct{index, rank1, rank2: int}) -> int {
                if a.rank1 < b.rank1 { return -1 }
                if a.rank1 > b.rank1 { return 1 }
                if a.rank2 < b.rank2 { return -1 }
                if a.rank2 > b.rank2 { return 1 }
                return 0
            })

            for item, i in sortable {
                sa[i] = item.index
            }

            new_rank := make([]int, n)
            defer delete(new_rank)

            new_rank[sa[0]] = 0
            for i := 1; i < n; i += 1 {
                prev_idx := sa[i - 1]
                curr_idx := sa[i]

                prev_rank1 := rank[prev_idx]
                prev_rank2 := rank[(prev_idx + k) % n]
                curr_rank1 := rank[curr_idx]
                curr_rank2 := rank[(curr_idx + k) % n]

                new_rank[curr_idx] = new_rank[prev_idx]
                if prev_rank1 != curr_rank1 || prev_rank2 != curr_rank2 {
                    new_rank[curr_idx] += 1
                }
            }

            copy(rank[:], new_rank[:])
            k *= 2
        }
    }

    transformed := make([]u8, n)
    original_idx := 0

    for i in 0..<n {
        suffix := sa[i]
        if suffix == 0 {
            transformed[i] = input[n - 1]
            original_idx = i
        } else {
            transformed[i] = input[suffix - 1]
        }
    }

    return BWTResult{transformed = transformed, original_idx = original_idx}
}

BWTEncode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    bwt_result: BWTResult,
    result_val: u32,
}

bwt_encode_prepare :: proc(bench: ^Benchmark) {
    b := cast(^BWTEncode)bench
    b.test_data = generate_test_data(b.size_val)
    b.result_val = 0
}

bwt_encode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    b := cast(^BWTEncode)bench

    if len(b.bwt_result.transformed) > 0 {
        delete(b.bwt_result.transformed)
        b.bwt_result.transformed = nil
    }

    b.bwt_result = bwt_transform(b.test_data)
    b.result_val += u32(len(b.bwt_result.transformed))
}

bwt_encode_checksum :: proc(bench: ^Benchmark) -> u32 {
    b := cast(^BWTEncode)bench
    return b.result_val
}

bwt_encode_cleanup :: proc(bench: ^Benchmark) {
    b := cast(^BWTEncode)bench
    delete(b.test_data)

    if len(b.bwt_result.transformed) > 0 {
        delete(b.bwt_result.transformed)
    }
}

create_bwtencode :: proc() -> ^Benchmark {
    bench := new(BWTEncode)
    bench.name = "Compress::BWTEncode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = bwt_encode_prepare
    bench.vtable.run = bwt_encode_run
    bench.vtable.checksum = bwt_encode_checksum
    bench.vtable.cleanup = bwt_encode_cleanup
    bench.size_val = config_i64(bench.name, "size")
    return cast(^Benchmark)bench
}

BWTDecode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    inverted:   []u8,
    bwt_result: BWTResult,
    result_val: u32,
}

bwt_inverse :: proc(bwt_result: BWTResult) -> []u8 {
    bwt := bwt_result.transformed
    n := len(bwt)
    if n == 0 {
        return make([]u8, 0)
    }

    counts: [256]int
    for byte in bwt {
        counts[byte] += 1
    }

    positions: [256]int
    total := 0
    for i in 0..<256 {
        positions[i] = total
        total += counts[i]
    }

    next := make([]int, n)
    defer delete(next)

    temp_counts: [256]int
    for i in 0..<n {
        byte := bwt[i]
        pos := positions[byte] + temp_counts[byte]
        next[pos] = i
        temp_counts[byte] += 1
    }

    result := make([]u8, n)
    idx := bwt_result.original_idx

    for i in 0..<n {
        idx = next[idx]
        result[i] = bwt[idx]
    }

    return result
}

bwt_decode_prepare :: proc(bench: ^Benchmark) {
    b := cast(^BWTDecode)bench

    encoder := create_bwtencode()
    defer destroy_bench(encoder)
    enc := cast(^BWTEncode)encoder
    enc.size_val = b.size_val
    encoder.vtable.prepare(encoder)
    encoder.vtable.run(encoder, 0)

    b.test_data = slice.clone(enc.test_data)

    b.bwt_result.transformed = slice.clone(enc.bwt_result.transformed)
    b.bwt_result.original_idx = enc.bwt_result.original_idx

    b.result_val = 0
}

bwt_decode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    b := cast(^BWTDecode)bench

    if len(b.inverted) > 0 {
        delete(b.inverted)
        b.inverted = nil
    }

    b.inverted = bwt_inverse(b.bwt_result)
    b.result_val += u32(len(b.inverted))
}

bwt_decode_cleanup :: proc(bench: ^Benchmark) {
    b := cast(^BWTDecode)bench
    delete(b.test_data)

    if len(b.inverted) > 0 {
        delete(b.inverted)
    }

    delete(b.bwt_result.transformed)
}

bwt_decode_checksum :: proc(bench: ^Benchmark) -> u32 {
    b := cast(^BWTDecode)bench
    res := b.result_val
    if slice.equal(b.inverted, b.test_data) {
        res += 100000
    }
    return res
}

create_bwtdecode :: proc() -> ^Benchmark {
    bench := new(BWTDecode)
    bench.name = "Compress::BWTDecode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = bwt_decode_prepare
    bench.vtable.run = bwt_decode_run
    bench.vtable.checksum = bwt_decode_checksum
    bench.vtable.cleanup = bwt_decode_cleanup
    bench.size_val = config_i64(bench.name, "size")
    return cast(^Benchmark)bench
}

HuffmanNode :: struct {
    frequency: int,
    byte_val:  u8,
    is_leaf:   bool,
    left:      ^HuffmanNode,
    right:     ^HuffmanNode,
}

HuffmanCodes :: struct {
    code_lengths: [256]int,
    codes:        [256]int,
}

EncodedResult :: struct {
    data:        []u8,
    bit_count:   int,
    frequencies: [256]int,
}

huffman_node_greater :: proc(a, b: ^HuffmanNode) -> bool {
    return a.frequency > b.frequency
}

heap_pop_node :: proc(heap_data: ^[dynamic]^HuffmanNode, greater: proc(a, b: ^HuffmanNode) -> bool) -> ^HuffmanNode {
    if len(heap_data) == 0 do return nil

    heap.pop(heap_data[:], greater)
    node := heap_data[len(heap_data)-1]

    pop(heap_data)

    return node
}

build_huffman_tree :: proc(frequencies: []int) -> ^HuffmanNode {
    heap_data := make([dynamic]^HuffmanNode, 0, 256)
    defer delete(heap_data)

    for i in 0..<256 {
        if frequencies[i] > 0 {
            node := new(HuffmanNode)
            node.frequency = frequencies[i]
            node.byte_val = u8(i)
            node.is_leaf = true
            node.left = nil
            node.right = nil
            append(&heap_data, node)
            heap.push(heap_data[:], huffman_node_greater)
        }
    }

    if len(heap_data) == 1 {
        node := heap_pop_node(&heap_data, huffman_node_greater)
        root := new(HuffmanNode)
        root.frequency = node.frequency
        root.is_leaf = false
        root.left = node
        root.right = new(HuffmanNode)
        root.right.frequency = 0
        root.right.byte_val = 0
        root.right.is_leaf = true
        return root
    }

    for len(heap_data) > 1 {
        left := heap_pop_node(&heap_data, huffman_node_greater)
        right := heap_pop_node(&heap_data, huffman_node_greater)

        parent := new(HuffmanNode)
        parent.frequency = left.frequency + right.frequency
        parent.is_leaf = false
        parent.left = left
        parent.right = right

        append(&heap_data, parent)
        heap.push(heap_data[:], huffman_node_greater)
    }

    return heap_pop_node(&heap_data, huffman_node_greater)
}

destroy_huffman_tree :: proc(node: ^HuffmanNode) {
    if node == nil do return
    if !node.is_leaf {
        destroy_huffman_tree(node.left)
        destroy_huffman_tree(node.right)
    }
    free(node)
}

build_huffman_codes :: proc(node: ^HuffmanNode, code: int, length: int, codes: ^HuffmanCodes) {
    if node == nil do return

    if node.is_leaf {
        if length > 0 || node.byte_val != 0 {
            idx := int(node.byte_val)
            codes.code_lengths[idx] = length
            codes.codes[idx] = code
        }
    } else {
        build_huffman_codes(node.left, code << 1, length + 1, codes)
        build_huffman_codes(node.right, (code << 1) | 1, length + 1, codes)
    }
}

huffman_encode :: proc(data: []u8, huffman_codes: ^HuffmanCodes, frequencies: [256]int) -> EncodedResult {

    result := make([dynamic]u8, 0, len(data) * 2)
    current_byte: u8 = 0
    bit_pos := 0
    total_bits := 0

    codes := huffman_codes.codes
    code_lengths := huffman_codes.code_lengths

    for byte in data {
        code := codes[byte]
        length := code_lengths[byte]

        for i := length - 1; i >= 0; i -= 1 {
            if (code & (1 << u8(i))) != 0 {
                current_byte |= 1 << u8(7 - bit_pos)
            }
            bit_pos += 1
            total_bits += 1

            if bit_pos == 8 {

                append(&result, current_byte)
                current_byte = 0
                bit_pos = 0
            }
        }
    }

    if bit_pos > 0 {
        append(&result, current_byte)
    }

    return EncodedResult{
        data = result[:],
        bit_count = total_bits,
        frequencies = frequencies,
    }
}

huffman_decode :: proc(encoded: []u8, root: ^HuffmanNode, bit_count: int) -> []u8 {
    if root == nil || len(encoded) == 0 {
        return {}
    }

    result := make([]u8, bit_count)
    result_size := 0

    current_node := root
    bits_processed := 0
    byte_index := 0

    for bits_processed < bit_count && byte_index < len(encoded) {
        byte_val := encoded[byte_index]
        byte_index += 1

        for bit_pos := 7; bit_pos >= 0; bit_pos -= 1 {
            if bits_processed >= bit_count {
                break
            }

            bit := ((byte_val >> u8(bit_pos)) & 1) == 1
            bits_processed += 1

            current_node = bit ? current_node.right : current_node.left

            if current_node.is_leaf {
                result[result_size] = current_node.byte_val
                result_size += 1
                current_node = root
            }
        }
    }

    return result[:result_size]
}

HuffEncode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    encoded:    EncodedResult,
    result_val: u32,
}

huff_encode_prepare :: proc(bench: ^Benchmark) {
    h := cast(^HuffEncode)bench
    h.test_data = generate_test_data(h.size_val)
    h.result_val = 0
}

huff_encode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    h := cast(^HuffEncode)bench

    frequencies: [256]int
    for byte in h.test_data {
        frequencies[byte] += 1
    }

    tree := build_huffman_tree(frequencies[:])
    defer destroy_huffman_tree(tree)

    codes: HuffmanCodes
    build_huffman_codes(tree, 0, 0, &codes)

    new_encoded := huffman_encode(h.test_data, &codes, frequencies)

    if len(h.encoded.data) > 0 {
        delete(h.encoded.data)
    }

    h.encoded = new_encoded
    h.result_val += u32(len(h.encoded.data))
}

huff_encode_checksum :: proc(bench: ^Benchmark) -> u32 {
    h := cast(^HuffEncode)bench
    return h.result_val
}

huff_encode_cleanup :: proc(bench: ^Benchmark) {
    h := cast(^HuffEncode)bench
    delete(h.test_data)

    if len(h.encoded.data) > 0 {
        delete(h.encoded.data)
    }
}

create_huffencode :: proc() -> ^Benchmark {
    bench := new(HuffEncode)
    bench.name = "Compress::HuffEncode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = huff_encode_prepare
    bench.vtable.run = huff_encode_run
    bench.vtable.checksum = huff_encode_checksum
    bench.vtable.cleanup = huff_encode_cleanup
    bench.size_val = config_i64(bench.name, "size")
    return cast(^Benchmark)bench
}

HuffDecode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    decoded:    []u8,
    encoded:    EncodedResult,
    result_val: u32,
}

huff_decode_prepare :: proc(bench: ^Benchmark) {
    h := cast(^HuffDecode)bench
    h.size_val = config_i64(h.name, "size")
    h.test_data = generate_test_data(h.size_val)

    encoder := create_huffencode()
    defer destroy_bench(encoder)
    enc := cast(^HuffEncode)encoder
    enc.size_val = h.size_val
    encoder.vtable.prepare(encoder)
    encoder.vtable.run(encoder, 0)

    h.encoded.data = slice.clone(enc.encoded.data)
    h.encoded.bit_count = enc.encoded.bit_count
    h.encoded.frequencies = enc.encoded.frequencies

    h.result_val = 0
}

huff_decode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    h := cast(^HuffDecode)bench

    tree := build_huffman_tree(h.encoded.frequencies[:])
    defer destroy_huffman_tree(tree)

    if h.decoded != nil {
        delete(h.decoded)
    }

    h.decoded = huffman_decode(h.encoded.data, tree, h.encoded.bit_count)
    h.result_val += u32(len(h.decoded))
}

huff_decode_checksum :: proc(bench: ^Benchmark) -> u32 {
    h := cast(^HuffDecode)bench
    res := h.result_val
    if h.decoded != nil && h.test_data != nil {
        if slice.equal(h.decoded, h.test_data) {
            res += 100000
        }
    }
    return res
}

huff_decode_cleanup :: proc(bench: ^Benchmark) {
    h := cast(^HuffDecode)bench

    if h.test_data != nil {
        delete(h.test_data)
        h.test_data = nil
    }

    if h.decoded != nil {
        delete(h.decoded)
        h.decoded = nil
    }

    if h.encoded.data != nil {
        delete(h.encoded.data)
        h.encoded.data = nil
    }
}

create_huffdecode :: proc() -> ^Benchmark {
    bench := new(HuffDecode)
    bench.name = "Compress::HuffDecode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = huff_decode_prepare
    bench.vtable.run = huff_decode_run
    bench.vtable.checksum = huff_decode_checksum
    bench.vtable.cleanup = huff_decode_cleanup
    return cast(^Benchmark)bench
}

ArithFreqTable :: struct {
    total: int,
    low:   [256]int,
    high:  [256]int,
}

BitOutputStream :: struct {
    buffer:       u8,
    bit_pos:      int,
    bytes:        [dynamic]u8,
    bits_written: int,
}

ArithEncodedResult :: struct {
    data:        []u8,
    bit_count:   int,
    frequencies: [256]int,
}

ArithEncode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    encoded:    ArithEncodedResult,
    result_val: u32,
}

arith_freq_table_new :: proc(frequencies: [256]int) -> ArithFreqTable {
    ft: ArithFreqTable
    ft.total = 0
    for f in frequencies {
        ft.total += f
    }

    cum := 0
    for i in 0..<256 {
        ft.low[i] = cum
        cum += frequencies[i]
        ft.high[i] = cum
    }

    return ft
}

bit_output_write_bit :: proc(out: ^BitOutputStream, bit: int) {
    out.buffer = u8((int(out.buffer) << 1) | (bit & 1))
    out.bit_pos += 1
    out.bits_written += 1

    if out.bit_pos == 8 {
        append_elem(&out.bytes, out.buffer)
        out.buffer = 0
        out.bit_pos = 0
    }
}

bit_output_flush :: proc(out: ^BitOutputStream) -> []u8 {
    if out.bit_pos > 0 {
        out.buffer = u8(int(out.buffer) << uint(8 - out.bit_pos))
        append_elem(&out.bytes, out.buffer)
    }
    return out.bytes[:]
}

arith_encode :: proc(data: []u8) -> ArithEncodedResult {
    frequencies: [256]int
    for byte in data {
        frequencies[byte] += 1
    }

    freq_table := arith_freq_table_new(frequencies)

    low: u64 = 0
    high: u64 = 0xFFFFFFFF
    pending := 0
    output: BitOutputStream

    for byte in data {
        idx := int(byte)
        range := high - low + 1

        high = low + (range * u64(freq_table.high[idx]) / u64(freq_table.total)) - 1
        low = low + (range * u64(freq_table.low[idx]) / u64(freq_table.total))

        for {
            if high < 0x80000000 {
                bit_output_write_bit(&output, 0)
                for _ in 0..<pending {
                    bit_output_write_bit(&output, 1)
                }
                pending = 0
            } else if low >= 0x80000000 {
                bit_output_write_bit(&output, 1)
                for _ in 0..<pending {
                    bit_output_write_bit(&output, 0)
                }
                pending = 0
                low -= 0x80000000
                high -= 0x80000000
            } else if low >= 0x40000000 && high < 0xC0000000 {
                pending += 1
                low -= 0x40000000
                high -= 0x40000000
            } else {
                break
            }

            low <<= 1
            high = (high << 1) | 1
            high &= 0xFFFFFFFF
        }
    }

    pending += 1
    if low < 0x40000000 {
        bit_output_write_bit(&output, 0)
        for _ in 0..<pending {
            bit_output_write_bit(&output, 1)
        }
    } else {
        bit_output_write_bit(&output, 1)
        for _ in 0..<pending {
            bit_output_write_bit(&output, 0)
        }
    }

    data_out := bit_output_flush(&output)
    return ArithEncodedResult{
        data = slice.clone(data_out),
        bit_count = output.bits_written,
        frequencies = frequencies,
    }
}

arith_encode_prepare :: proc(bench: ^Benchmark) {
    a := cast(^ArithEncode)bench
    a.test_data = generate_test_data(a.size_val)
    a.result_val = 0
}

arith_encode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    a := cast(^ArithEncode)bench

    new_encoded := arith_encode(a.test_data)

    if len(a.encoded.data) > 0 {
        delete(a.encoded.data)
    }

    a.encoded = new_encoded
    a.result_val += u32(len(a.encoded.data))
}

arith_encode_checksum :: proc(bench: ^Benchmark) -> u32 {
    a := cast(^ArithEncode)bench
    return a.result_val
}

arith_encode_cleanup :: proc(bench: ^Benchmark) {
    a := cast(^ArithEncode)bench
    delete(a.test_data)

    if len(a.encoded.data) > 0 {
        delete(a.encoded.data)
    }
}

create_arithencode :: proc() -> ^Benchmark {
    bench := new(ArithEncode)
    bench.name = "Compress::ArithEncode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = arith_encode_prepare
    bench.vtable.run = arith_encode_run
    bench.vtable.checksum = arith_encode_checksum
    bench.vtable.cleanup = arith_encode_cleanup
    bench.size_val = config_i64(bench.name, "size")
    return bench
}

BitInputStream :: struct {
    bytes:       []u8,
    byte_pos:    int,
    bit_pos:     int,
    current_byte: u8,
}

ArithDecode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    decoded:    []u8,
    encoded:    ArithEncodedResult,
    result_val: u32,
}

bit_input_read_bit :: proc(inp: ^BitInputStream) -> int {
    if inp.bit_pos == 8 {
        inp.byte_pos += 1
        inp.bit_pos = 0
        inp.current_byte = inp.byte_pos < len(inp.bytes) ? inp.bytes[inp.byte_pos] : 0
    }

    bit := (int(inp.current_byte) >> uint(7 - inp.bit_pos)) & 1
    inp.bit_pos += 1
    return bit
}

arith_decode :: proc(encoded: ArithEncodedResult) -> []u8 {
    total := 0
    for f in encoded.frequencies {
        total += f
    }
    data_size := total

    low_table, high_table: [256]int
    cum := 0
    for i in 0..<256 {
        low_table[i] = cum
        cum += encoded.frequencies[i]
        high_table[i] = cum
    }

    result := make([]u8, data_size)

    input: BitInputStream
    input.bytes = encoded.data
    input.byte_pos = 0
    input.bit_pos = 0
    input.current_byte = len(encoded.data) > 0 ? encoded.data[0] : 0

    value: u64 = 0
    for _ in 0..<32 {
        value = (value << 1) | u64(bit_input_read_bit(&input))
    }

    low: u64 = 0
    high: u64 = 0xFFFFFFFF

    for j in 0..<data_size {
        range := high - low + 1
        scaled := ((value - low + 1) * u64(total) - 1) / range

        symbol := 0
        for symbol < 255 && u64(high_table[symbol]) <= scaled {
            symbol += 1
        }

        result[j] = u8(symbol)

        high = low + (range * u64(high_table[symbol]) / u64(total)) - 1
        low = low + (range * u64(low_table[symbol]) / u64(total))

        for {
            if high < 0x80000000 {

            } else if low >= 0x80000000 {
                value -= 0x80000000
                low -= 0x80000000
                high -= 0x80000000
            } else if low >= 0x40000000 && high < 0xC0000000 {
                value -= 0x40000000
                low -= 0x40000000
                high -= 0x40000000
            } else {
                break
            }

            low <<= 1
            high = (high << 1) | 1
            value = (value << 1) | u64(bit_input_read_bit(&input))
        }
    }

    return result
}

arith_decode_prepare :: proc(bench: ^Benchmark) {
    a := cast(^ArithDecode)bench
    a.size_val = config_i64("Compress::ArithDecode", "size")
    a.test_data = generate_test_data(a.size_val)

    encoder := create_arithencode()
    defer destroy_bench(encoder)
    enc := cast(^ArithEncode)encoder
    enc.size_val = a.size_val
    encoder.vtable.prepare(encoder)
    encoder.vtable.run(encoder, 0)

    a.encoded.data = slice.clone(enc.encoded.data)
    a.encoded.bit_count = enc.encoded.bit_count
    a.encoded.frequencies = enc.encoded.frequencies
    a.result_val = 0
}

arith_decode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    a := cast(^ArithDecode)bench

    if a.decoded != nil {
        delete(a.decoded)
    }

    a.decoded = arith_decode(a.encoded)
    a.result_val += u32(len(a.decoded))
}

arith_decode_checksum :: proc(bench: ^Benchmark) -> u32 {
    a := cast(^ArithDecode)bench
    res := a.result_val
    if a.decoded != nil && a.test_data != nil {
        if slice.equal(a.decoded, a.test_data) {
            res += 100000
        }
    }
    return res
}

arith_decode_cleanup :: proc(bench: ^Benchmark) {
    a := cast(^ArithDecode)bench

    if a.test_data != nil {
        delete(a.test_data)
    }
    if a.decoded != nil {
        delete(a.decoded)
    }
    if a.encoded.data != nil {
        delete(a.encoded.data)
    }
}

create_arithdecode :: proc() -> ^Benchmark {
    bench := new(ArithDecode)
    bench.name = "Compress::ArithDecode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = arith_decode_prepare
    bench.vtable.run = arith_decode_run
    bench.vtable.checksum = arith_decode_checksum
    bench.vtable.cleanup = arith_decode_cleanup
    return bench
}

LZWResult :: struct {
    data:      []u8,
    dict_size: int,
}

LZWEncode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    encoded:    LZWResult,
    result_val: u32,
}

lzw_encode :: proc(input: []u8) -> LZWResult {
    if len(input) == 0 {
        return LZWResult{data = make([]u8, 0), dict_size = 256}
    }

    arena: virtual.Arena
    err := virtual.arena_init_growing(&arena)
    defer virtual.arena_destroy(&arena)

    arena_alloc := virtual.arena_allocator(&arena)

    dict := make(map[string]int, 4096, arena_alloc)
    defer delete(dict)

    for i in 0..<256 {
        bytes := make([]u8, 1, arena_alloc)
        bytes[0] = u8(i)
        dict[string(bytes)] = i
    }

    next_code := 256

    result := make([dynamic]u8)
    defer delete(result)
    reserve(&result, len(input) * 2)

    current_start := 0
    current_len := 1

    temp_buf: [4096]u8

    i := 1
    for i < len(input) {
        next_char := input[i]

        if current_len + 1 <= 4096 {
            copy(temp_buf[:current_len], input[current_start:current_start+current_len])
            temp_buf[current_len] = next_char
            new_str := string(temp_buf[:current_len+1])

            if new_str in dict {
                current_len += 1
            } else {
                code := dict[string(input[current_start:current_start+current_len])]
                append(&result, u8((code >> 8) & 0xFF))
                append(&result, u8(code & 0xFF))

                key_bytes := make([]u8, len(new_str), arena_alloc)
                copy(key_bytes, temp_buf[:current_len+1])
                dict[string(key_bytes)] = next_code
                next_code += 1

                current_start = i
                current_len = 1
            }
        } else {
            bytes := make([]u8, current_len + 1, arena_alloc)
            copy(bytes[:current_len], input[current_start:current_start+current_len])
            bytes[current_len] = next_char
            new_str := string(bytes)

            if new_str in dict {
                current_len += 1
            } else {
                code := dict[string(input[current_start:current_start+current_len])]
                append(&result, u8((code >> 8) & 0xFF))
                append(&result, u8(code & 0xFF))

                dict[new_str] = next_code
                next_code += 1

                current_start = i
                current_len = 1
            }
        }
        i += 1
    }

    last_slice := input[current_start:current_start+current_len]
    code := dict[string(last_slice)]
    append(&result, u8((code >> 8) & 0xFF))
    append(&result, u8(code & 0xFF))

    result_copy := slice.clone(result[:])

    return LZWResult{
        data = result_copy,
        dict_size = next_code,
    }
}

lzw_decode :: proc(encoded: LZWResult) -> []u8 {
    if len(encoded.data) == 0 {
        return make([]u8, 0)
    }

    arena: virtual.Arena
    err := virtual.arena_init_growing(&arena)
    defer virtual.arena_destroy(&arena)

    arena_alloc := virtual.arena_allocator(&arena)

    dict := make([dynamic][]u8, 0, 4096, arena_alloc)
    defer delete(dict)

    for i in 0..<256 {
        bytes := make([]u8, 1, arena_alloc)
        bytes[0] = u8(i)
        append(&dict, bytes)
    }

    result := make([dynamic]u8)
    defer delete(result)
    reserve(&result, len(encoded.data) * 4)

    data := encoded.data
    pos := 0

    high := int(data[pos])
    low := int(data[pos + 1])
    old_code := (high << 8) | low
    pos += 2

    old_str := dict[old_code]
    append(&result, ..old_str)

    next_code := 256

    for pos < len(data) {
        high = int(data[pos])
        low = int(data[pos + 1])
        new_code := (high << 8) | low
        pos += 2

        current_str: []u8
        if new_code < len(dict) {
            current_str = dict[new_code]
        } else if new_code == next_code {

            bytes := make([]u8, len(old_str) + 1, arena_alloc)
            copy(bytes[:len(old_str)], old_str)
            bytes[len(old_str)] = old_str[0]
            current_str = bytes
        } else {
            panic("Invalid code")
        }

        append(&result, ..current_str)

        bytes := make([]u8, len(old_str) + 1, arena_alloc)
        copy(bytes[:len(old_str)], old_str)
        bytes[len(old_str)] = current_str[0]
        append(&dict, bytes)

        next_code += 1
        old_code = new_code
        old_str = current_str
    }

    return slice.clone(result[:])
}

lzw_encode_prepare :: proc(bench: ^Benchmark) {
    l := cast(^LZWEncode)bench
    l.test_data = generate_test_data(l.size_val)
    l.result_val = 0
}

lzw_encode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    l := cast(^LZWEncode)bench

    new_encoded := lzw_encode(l.test_data)

    if len(l.encoded.data) > 0 {
        delete(l.encoded.data)
    }

    l.encoded = new_encoded
    l.result_val += u32(len(l.encoded.data))
}

lzw_encode_checksum :: proc(bench: ^Benchmark) -> u32 {
    l := cast(^LZWEncode)bench
    return l.result_val
}

lzw_encode_cleanup :: proc(bench: ^Benchmark) {
    l := cast(^LZWEncode)bench
    delete(l.test_data)

    if len(l.encoded.data) > 0 {
        delete(l.encoded.data)
    }
}

create_lzwencode :: proc() -> ^Benchmark {
    bench := new(LZWEncode)
    bench.name = "Compress::LZWEncode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = lzw_encode_prepare
    bench.vtable.run = lzw_encode_run
    bench.vtable.checksum = lzw_encode_checksum
    bench.vtable.cleanup = lzw_encode_cleanup
    bench.size_val = config_i64(bench.name, "size")
    return bench
}

LZWDecode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    decoded:    []u8,
    encoded:    LZWResult,
    result_val: u32,
}

lzw_decode_prepare :: proc(bench: ^Benchmark) {
    l := cast(^LZWDecode)bench
    l.size_val = config_i64("Compress::LZWDecode", "size")
    l.test_data = generate_test_data(l.size_val)

    encoder := create_lzwencode()
    defer destroy_bench(encoder)
    enc := cast(^LZWEncode)encoder
    enc.size_val = l.size_val
    encoder.vtable.prepare(encoder)
    encoder.vtable.run(encoder, 0)

    l.encoded.data = slice.clone(enc.encoded.data)
    l.encoded.dict_size = enc.encoded.dict_size
    l.result_val = 0
}

lzw_decode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    l := cast(^LZWDecode)bench

    if l.decoded != nil {
        delete(l.decoded)
    }

    l.decoded = lzw_decode(l.encoded)
    l.result_val += u32(len(l.decoded))
}

lzw_decode_checksum :: proc(bench: ^Benchmark) -> u32 {
    l := cast(^LZWDecode)bench
    res := l.result_val
    if l.decoded != nil && l.test_data != nil {
        if slice.equal(l.decoded, l.test_data) {
            res += 100000
        }
    }
    return res
}

lzw_decode_cleanup :: proc(bench: ^Benchmark) {
    l := cast(^LZWDecode)bench

    if l.test_data != nil {
        delete(l.test_data)
    }
    if l.decoded != nil {
        delete(l.decoded)
    }
    if l.encoded.data != nil {
        delete(l.encoded.data)
    }
}

create_lzwdecode :: proc() -> ^Benchmark {
    bench := new(LZWDecode)
    bench.name = "Compress::LZWDecode"
    bench.vtable = default_vtable()
    bench.vtable.prepare = lzw_decode_prepare
    bench.vtable.run = lzw_decode_run
    bench.vtable.checksum = lzw_decode_checksum
    bench.vtable.cleanup = lzw_decode_cleanup
    return bench
}