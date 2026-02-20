using DataStructures

mutable struct BWTHuffEncode <: AbstractBenchmark
    size::Int64
    result::UInt32
    test_data::Vector{UInt8}

    function BWTHuffEncode()
        size_val = Helper.config_i64("BWTHuffEncode", "size")
        new(size_val, UInt32(0), UInt8[])
    end
end

name(b::BWTHuffEncode)::String = "BWTHuffEncode"

struct BWTResult
    transformed::Vector{UInt8}
    original_idx::Int64
end

struct EncodedResult
    data::Vector{UInt8}
    bit_count::Int64
end

struct CompressedData
    bwt_result::BWTResult
    frequencies::Vector{Int64}
    encoded_bits::Vector{UInt8}
    original_bit_count::Int64
end

mutable struct HuffmanNode
    frequency::Int64
    byte_val::UInt8
    is_leaf::Bool
    left::Union{HuffmanNode,Nothing}
    right::Union{HuffmanNode,Nothing}

    function HuffmanNode(frequency::Int64, byte_val::UInt8)
        new(frequency, byte_val, true, nothing, nothing)
    end

    function HuffmanNode(frequency::Int64, left::HuffmanNode, right::HuffmanNode)
        new(frequency, 0x00, false, left, right)
    end
end

function Base.isless(a::HuffmanNode, b::HuffmanNode)
    return a.frequency < b.frequency
end

function bwt_transform(input::Vector{UInt8})::BWTResult
    n = length(input)
    if n == 0
        return BWTResult(Vector{UInt8}(), 0)
    end

    doubled = Vector{UInt8}(undef, n * 2)
    for i = 1:n
        doubled[i] = input[i]
        doubled[i+n] = input[i]
    end

    sa = [i for i = 0:(n-1)]

    buckets = [Int[] for _ = 1:256]

    for idx in sa
        first_char = input[idx+1]
        push!(buckets[first_char+1], idx)
    end

    pos = 1
    for bucket in buckets
        for idx in bucket
            sa[pos] = idx
            pos += 1
        end
    end

    if n > 1

        rank = Vector{Int}(undef, n)
        current_rank = 0
        prev_char = input[sa[1]+1]

        for i = 1:n
            idx = sa[i]
            curr_char = input[idx+1]
            if curr_char != prev_char
                current_rank += 1
                prev_char = curr_char
            end
            rank[idx+1] = current_rank
        end

        k = 1
        while k < n

            pairs = Vector{Tuple{Int,Int}}(undef, n)
            for i = 1:n
                idx = i - 1
                first = rank[i]
                second = rank[((idx+k)%n)+1]
                pairs[i] = (first, second)
            end

            sort!(sa, by = idx -> pairs[idx+1])

            new_rank = Vector{Int}(undef, n)
            new_rank[sa[1]+1] = 0

            for i = 2:n
                prev_idx = sa[i-1] + 1
                curr_idx = sa[i] + 1
                if pairs[prev_idx] != pairs[curr_idx]
                    new_rank[curr_idx] = new_rank[prev_idx] + 1
                else
                    new_rank[curr_idx] = new_rank[prev_idx]
                end
            end

            rank = new_rank
            k *= 2
        end
    end

    transformed = Vector{UInt8}(undef, n)
    original_idx = 0

    for i = 1:n
        suffix = sa[i]
        if suffix == 0
            transformed[i] = input[n]
            original_idx = i - 1
        else
            transformed[i] = input[suffix]
        end
    end

    return BWTResult(transformed, original_idx)
end

function bwt_inverse(bwt_result::BWTResult)::Vector{UInt8}
    bwt = bwt_result.transformed
    n = length(bwt)
    if n == 0
        return Vector{UInt8}()
    end

    counts = zeros(Int, 256)
    for byte in bwt
        counts[byte+1] += 1
    end

    positions = zeros(Int, 256)
    total = 0
    for i = 1:256
        positions[i] = total
        total += counts[i]
    end

    next = Vector{Int}(undef, n)
    temp_counts = zeros(Int, 256)

    for i = 1:n
        byte = bwt[i]
        idx = byte + 1
        pos = positions[idx] + temp_counts[idx] + 1
        next[pos] = i
        temp_counts[idx] += 1
    end

    result = Vector{UInt8}(undef, n)
    idx = bwt_result.original_idx + 1

    for i = 1:n
        idx = next[idx]
        result[i] = bwt[idx]
    end

    return result
end

function build_huffman_tree(frequencies::Vector{Int64})::HuffmanNode

    heap = BinaryMinHeap{HuffmanNode}()

    for i = 1:256
        freq = frequencies[i]
        if freq > 0
            push!(heap, HuffmanNode(freq, UInt8(i-1)))
        end
    end

    if length(heap) == 1
        node = pop!(heap)
        dummy = HuffmanNode(0, 0x00)
        return HuffmanNode(node.frequency, node, dummy)
    end

    while length(heap) > 1
        left = pop!(heap)
        right = pop!(heap)
        parent = HuffmanNode(left.frequency + right.frequency, left, right)
        push!(heap, parent)
    end

    return pop!(heap)
end

mutable struct HuffmanCodes
    code_lengths::Vector{Int64}
    codes::Vector{Int64}

    function HuffmanCodes()
        new(zeros(Int64, 256), zeros(Int64, 256))
    end
end

function build_huffman_codes(
    node::HuffmanNode,
    code::Int64,
    length::Int64,
    huffman_codes::HuffmanCodes,
)
    if node.is_leaf
        if length > 0 || node.byte_val != 0x00
            idx = Int64(node.byte_val) + 1
            huffman_codes.code_lengths[idx] = length
            huffman_codes.codes[idx] = code
        end
    else
        if node.left !== nothing
            build_huffman_codes(node.left, code << 1, length + 1, huffman_codes)
        end
        if node.right !== nothing
            build_huffman_codes(node.right, (code << 1) | 1, length + 1, huffman_codes)
        end
    end
end

function huffman_encode(data::Vector{UInt8}, huffman_codes::HuffmanCodes)::EncodedResult
    result = UInt8[]
    current_byte = 0x00
    bit_pos = 0
    total_bits = 0

    for byte in data
        idx = Int64(byte) + 1
        code = huffman_codes.codes[idx]
        length = huffman_codes.code_lengths[idx]

        for i = (length-1):-1:0
            if ((code >> i) & 1) == 1
                current_byte |= 0x01 << (7 - bit_pos)
            end
            bit_pos += 1
            total_bits += 1

            if bit_pos == 8
                push!(result, current_byte)
                current_byte = 0x00
                bit_pos = 0
            end
        end
    end

    if bit_pos > 0
        push!(result, current_byte)
    end

    return EncodedResult(result, total_bits)
end

function huffman_decode(
    encoded::Vector{UInt8},
    root::HuffmanNode,
    bit_count::Int64,
)::Vector{UInt8}
    result = UInt8[]
    current_node = root
    bits_processed = 0
    byte_index = 1

    while bits_processed < bit_count && byte_index <= length(encoded)
        byte_val = encoded[byte_index]
        byte_index += 1

        for bit_pos = 7:-1:0
            if bits_processed >= bit_count
                break
            end

            bit = ((byte_val >> bit_pos) & 0x01) == 0x01
            bits_processed += 1

            current_node = bit ? current_node.right : current_node.left

            if current_node.is_leaf
                push!(result, current_node.byte_val)
                current_node = root
            end
        end
    end

    return result
end

function compress(data::Vector{UInt8})::CompressedData

    bwt_result = bwt_transform(data)

    frequencies = zeros(Int64, 256)
    for byte in bwt_result.transformed
        frequencies[byte+1] += 1
    end

    huffman_tree = build_huffman_tree(frequencies)

    huffman_codes = HuffmanCodes()
    build_huffman_codes(huffman_tree, 0, 0, huffman_codes)

    encoded = huffman_encode(bwt_result.transformed, huffman_codes)

    return CompressedData(bwt_result, frequencies, encoded.data, encoded.bit_count)
end

function decompress(compressed::CompressedData)::Vector{UInt8}

    huffman_tree = build_huffman_tree(compressed.frequencies)

    decoded =
        huffman_decode(compressed.encoded_bits, huffman_tree, compressed.original_bit_count)

    bwt_result = BWTResult(decoded, compressed.bwt_result.original_idx)
    return bwt_inverse(bwt_result)
end

function generate_test_data(size::Int64)::Vector{UInt8}
    pattern = b"ABRACADABRA"
    pattern_len = length(pattern)
    data = Vector{UInt8}(undef, size)

    for i = 1:size
        data[i] = pattern[((i-1)%pattern_len)+1]
    end

    return data
end

function prepare(b::BWTHuffEncode)
    b.test_data = generate_test_data(b.size)
end

function run(b::BWTHuffEncode, iteration_id::Int64)
    compressed = compress(b.test_data)
    b.result += UInt32(length(compressed.encoded_bits))
end

function checksum(b::BWTHuffEncode)::UInt32
    return b.result
end

mutable struct BWTHuffDecode <: AbstractBenchmark
    size::Int64
    result::UInt32
    test_data::Vector{UInt8}
    compressed::Union{CompressedData,Nothing}
    decompressed::Union{Vector{UInt8},Nothing}

    function BWTHuffDecode()
        size_val = Helper.config_i64("BWTHuffDecode", "size")
        new(size_val, UInt32(0), UInt8[], nothing, nothing)
    end
end

name(b::BWTHuffDecode)::String = "BWTHuffDecode"

function prepare(b::BWTHuffDecode)
    b.test_data = generate_test_data(b.size)
    b.compressed = compress(b.test_data)
end

function run(b::BWTHuffDecode, iteration_id::Int64)
    if b.compressed === nothing
        error("Compressed data not initialized. Call prepare() first.")
    end

    b.decompressed = decompress(b.compressed)
    b.result += UInt32(length(b.decompressed))
end

function checksum(b::BWTHuffDecode)::UInt32
    res = b.result

    if b.decompressed !== nothing && b.test_data !== nothing
        if b.decompressed == b.test_data
            res += 1000000
        end
    end

    return res
end
