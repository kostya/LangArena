package benchmark

import "core:fmt"
import "core:mem"
import "core:slice"
import "core:slice/heap"
import "core:sort"

BWTResult :: struct {
    transformed: []u8,
    original_idx: int,
}

Sortable_Suffix :: struct {
    index: int,    
    rank1: int,    
    rank2: int,    
}

bwt_transform :: proc(input: []u8) -> BWTResult {
    n := len(input)
    if n == 0 {
        return BWTResult{transformed = make([]u8, 0), original_idx = 0}
    }

    sa := make([]int, n)
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
        first_char := input[idx]
        append(&buckets[first_char], idx)
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

            sortable := make([]Sortable_Suffix, n)
            defer delete(sortable)

            for i in 0..<n {
                suffix_idx := sa[i]
                sortable[i] = Sortable_Suffix{
                    index = suffix_idx,
                    rank1 = rank[suffix_idx],
                    rank2 = rank[(suffix_idx + k) % n],
                }
            }

            sort.quick_sort_proc(sortable, proc(a, b: Sortable_Suffix) -> int {

                if a.rank1 < b.rank1 {
                    return -1
                } else if a.rank1 > b.rank1 {
                    return 1
                } else if a.rank2 < b.rank2 {
                    return -1
                } else if a.rank2 > b.rank2 {
                    return 1
                }
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

    delete(sa)

    return BWTResult{transformed = transformed, original_idx = original_idx}
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

HuffmanNode :: struct {
    frequency: int,
    byte_val:  u8,
    is_leaf:   bool,
    left:      ^HuffmanNode,
    right:     ^HuffmanNode,
}

huffman_node_greater :: proc(a, b: ^HuffmanNode) -> bool {
    return a.frequency > b.frequency  
}

heap_pop_node :: proc(heap_data: ^[dynamic]^HuffmanNode, greater: proc(a, b: ^HuffmanNode) -> bool) -> ^HuffmanNode {
    if len(heap_data) == 0 do return nil

    heap.pop(heap_data[:], greater)

    node := heap_data[len(heap_data)-1]

    ordered_remove(heap_data, len(heap_data)-1)

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

        dummy := new(HuffmanNode)
        dummy.frequency = 0
        dummy.byte_val = 0
        dummy.is_leaf = true
        dummy.left = nil
        dummy.right = nil
        root.right = dummy

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

    if len(heap_data) == 0 do return nil
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

HuffmanCodes :: struct {
    code_lengths: [256]int,
    codes:        [256]int,
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

EncodedResult :: struct {
    data:      []u8,
    bit_count: int,
}

huffman_encode :: proc(data: []u8, codes: ^HuffmanCodes) -> EncodedResult {

    result := make([]u8, len(data) * 2)
    current_byte: u8 = 0
    bit_pos := 0
    byte_index := 0
    total_bits := 0

    for byte in data {
        idx := int(byte)
        code := codes.codes[idx]
        length := codes.code_lengths[idx]

        for i := length - 1; i >= 0; i -= 1 {
            if (code & (1 << u8(i))) != 0 {
                current_byte |= 1 << u8(7 - bit_pos)
            }
            bit_pos += 1
            total_bits += 1

            if bit_pos == 8 {
                result[byte_index] = current_byte
                byte_index += 1
                current_byte = 0
                bit_pos = 0
            }
        }
    }

    if bit_pos > 0 {
        result[byte_index] = current_byte
        byte_index += 1
    }

    return EncodedResult{data = result[:byte_index], bit_count = total_bits}
}

huffman_decode :: proc(encoded: []u8, root: ^HuffmanNode, bit_count: int) -> []u8 {
    result := make([dynamic]u8, 0, bit_count / 4 + 1)

    current_node := root
    bits_processed := 0
    byte_index := 0

    outer_loop: for bits_processed < bit_count && byte_index < len(encoded) {
        byte_val := encoded[byte_index]
        byte_index += 1

        for bit_pos := 7; bit_pos >= 0; bit_pos -= 1 {
            if bits_processed >= bit_count {
                break outer_loop
            }

            bit := ((byte_val >> u8(bit_pos)) & 1) == 1
            bits_processed += 1

            if bit {
                current_node = current_node.right
            } else {
                current_node = current_node.left
            }

            if current_node.is_leaf {
                if current_node.byte_val != 0 {
                    append(&result, current_node.byte_val)
                }
                current_node = root
            }
        }
    }

    return slice.to_bytes(result[:])
}

CompressedData :: struct {
    bwt_result:        BWTResult,
    frequencies:       [256]int,  
    encoded_bits:      []u8,
    original_bit_count: int,
}

compress_data :: proc(data: []u8) -> CompressedData {

    bwt_result := bwt_transform(data)

    frequencies: [256]int
    for byte in bwt_result.transformed {
        frequencies[byte] += 1
    }

    huffman_tree := build_huffman_tree(frequencies[:])
    defer destroy_huffman_tree(huffman_tree)

    huffman_codes: HuffmanCodes
    build_huffman_codes(huffman_tree, 0, 0, &huffman_codes)

    encoded := huffman_encode(bwt_result.transformed, &huffman_codes)

    return CompressedData{
        bwt_result = bwt_result,
        frequencies = frequencies,
        encoded_bits = encoded.data,
        original_bit_count = encoded.bit_count,
    }
}

decompress_data :: proc(compressed: ^CompressedData) -> []u8 {

    freq_slice := compressed.frequencies[:]

    huffman_tree := build_huffman_tree(freq_slice)
    defer destroy_huffman_tree(huffman_tree)

    decoded := huffman_decode(
        compressed.encoded_bits,
        huffman_tree,
        compressed.original_bit_count
    )

    bwt_result := BWTResult{
        transformed = decoded,
        original_idx = compressed.bwt_result.original_idx,
    }

    result := bwt_inverse(bwt_result)
    delete(decoded)

    return result
}

generate_test_data :: proc(data_size: i64) -> []u8 {
    pattern := "ABRACADABRA"
    data := make([]u8, int(data_size))

    for i in 0..<int(data_size) {
        data[i] = pattern[i % len(pattern)]
    }

    return data
}

BWTHuffEncode :: struct {
    using base: Benchmark,
    size_val:   i64,
    test_data:  []u8,
    result_val: u32,
}

bwthuffencode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    benc := cast(^BWTHuffEncode)bench

    compressed := compress_data(benc.test_data)
    benc.result_val += u32(len(compressed.encoded_bits))

    delete(compressed.bwt_result.transformed)
    delete(compressed.encoded_bits)
}

bwthuffencode_checksum :: proc(bench: ^Benchmark) -> u32 {
    benc := cast(^BWTHuffEncode)bench
    return benc.result_val
}

bwthuffencode_prepare :: proc(bench: ^Benchmark) {
    pd := cast(^BWTHuffEncode)bench
    pd.size_val = config_i64("BWTHuffEncode", "size")
    pd.result_val = 0
    pd.test_data = generate_test_data(pd.size_val)
}

bwthuffencode_cleanup :: proc(bench: ^Benchmark) {
    benc := cast(^BWTHuffEncode)bench
    delete(benc.test_data)
}

create_bwthuffencode :: proc() -> ^Benchmark {
    bench := new(BWTHuffEncode)
    bench.name = "BWTHuffEncode"
    bench.vtable = default_vtable()

    bench.vtable.run = bwthuffencode_run
    bench.vtable.checksum = bwthuffencode_checksum
    bench.vtable.prepare = bwthuffencode_prepare
    bench.vtable.cleanup = bwthuffencode_cleanup

    return cast(^Benchmark)bench
}

BWTHuffDecode :: struct {
    using base: Benchmark,
    size_val:         i64,
    test_data:        []u8,
    result_val:       u32,
    compressed_data:  ^CompressedData,  
}

bwthuffdecode_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bdec := cast(^BWTHuffDecode)bench

    if bdec.compressed_data != nil {
        decompressed := decompress_data(bdec.compressed_data)

        bdec.result_val = bdec.result_val + u32(len(decompressed))
        delete(decompressed)  
    }
}

bwthuffdecode_checksum :: proc(bench: ^Benchmark) -> u32 {
    bdec := cast(^BWTHuffDecode)bench

    if bdec.compressed_data != nil {
        decompressed := decompress_data(bdec.compressed_data)

        if len(decompressed) != len(bdec.test_data) {
            delete(decompressed)
            return bdec.result_val  
        }

        match := true
        for i in 0..<len(decompressed) {
            if decompressed[i] != bdec.test_data[i] {
                match = false
                break
            }
        }

        delete(decompressed)

        if match {
            return bdec.result_val + 1000000
        }
    }

    return bdec.result_val
}

bwthuffdecode_prepare :: proc(bench: ^Benchmark) {
    bdec := cast(^BWTHuffDecode)bench
    bdec.size_val = config_i64("BWTHuffDecode", "size")
    bdec.result_val = 0

    bdec.test_data = generate_test_data(bdec.size_val)

    compressed := compress_data(bdec.test_data)

    bdec.compressed_data = new(CompressedData)
    bdec.compressed_data^ = compressed

}

bwthuffdecode_cleanup :: proc(bench: ^Benchmark) {
    bdec := cast(^BWTHuffDecode)bench

    delete(bdec.test_data)
    bdec.test_data = nil

    if bdec.compressed_data != nil {

        delete(bdec.compressed_data.bwt_result.transformed)
        delete(bdec.compressed_data.encoded_bits)

        free(bdec.compressed_data)
        bdec.compressed_data = nil
    }
}

create_bwthuffdecode :: proc() -> ^Benchmark {
    bench := new(BWTHuffDecode)
    bench.name = "BWTHuffDecode"
    bench.vtable = default_vtable()

    bench.vtable.run = bwthuffdecode_run
    bench.vtable.checksum = bwthuffdecode_checksum
    bench.vtable.prepare = bwthuffdecode_prepare
    bench.vtable.cleanup = bwthuffdecode_cleanup

    return cast(^Benchmark)bench
}