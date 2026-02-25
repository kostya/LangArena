using DataStructures

function generate_test_data(size::Int64)::Vector{UInt8}
    pattern = b"ABRACADABRA"
    pattern_len = length(pattern)
    data = Vector{UInt8}(undef, size)

    for i = 1:size
        data[i] = pattern[((i-1)%pattern_len)+1]
    end

    return data
end

struct BWTResult
    transformed::Vector{UInt8}
    original_idx::Int64
end

mutable struct BWTEncode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    bwt_result::BWTResult
    result_val::UInt32

    function BWTEncode()
        size_val = Helper.config_i64("Compress::BWTEncode", "size")
        new(size_val, UInt8[], BWTResult(UInt8[], 0), UInt32(0))
    end
end

function name(::BWTEncode)::String
    return "Compress::BWTEncode"
end

function bwt_transform(input::Vector{UInt8})::BWTResult
    n = length(input)
    if n == 0
        return BWTResult(Vector{UInt8}(), 0)
    end

    sa = collect(0:(n-1))

    counts = zeros(Int, 256)
    for i = 1:n
        counts[input[i]+1] += 1
    end

    positions = zeros(Int, 256)
    total = 0
    for i = 1:256
        positions[i] = total
        total += counts[i]
        counts[i] = 0
    end

    temp_sa = Vector{Int}(undef, n)
    for i = 1:n
        byte_val = input[i] + 1
        pos = positions[byte_val] + counts[byte_val] + 1
        temp_sa[pos] = i - 1
        counts[byte_val] += 1
    end
    sa = temp_sa

    if n > 1
        rank = Vector{Int}(undef, n)
        current_rank = 0
        prev_char = input[sa[1]+1]

        for i = 1:n
            idx = sa[i] + 1
            curr_char = input[idx]
            if curr_char != prev_char
                current_rank += 1
                prev_char = curr_char
            end
            rank[idx] = current_rank
        end

        k = 1
        while k < n

            pairs = Vector{Tuple{Int,Int}}(undef, n)
            for i = 1:n
                idx = i - 1
                pairs[i] = (rank[i], rank[((idx+k)%n)+1])
            end

            sort!(sa, by = idx -> pairs[idx+1])

            new_rank = Vector{Int}(undef, n)
            new_rank[sa[1]+1] = 0

            for i = 2:n
                prev_idx = sa[i-1] + 1
                curr_idx = sa[i] + 1
                new_rank[curr_idx] =
                    new_rank[prev_idx] + (pairs[prev_idx] != pairs[curr_idx] ? 1 : 0)
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

function prepare(b::BWTEncode)
    b.test_data = generate_test_data(b.size_val)
    b.result_val = 0
end

function run(b::BWTEncode, iteration_id::Int64)
    b.bwt_result = bwt_transform(b.test_data)
    b.result_val += UInt32(length(b.bwt_result.transformed))
end

function checksum(b::BWTEncode)::UInt32
    return b.result_val
end

mutable struct BWTDecode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    inverted::Vector{UInt8}
    bwt_result::BWTResult
    result_val::UInt32

    function BWTDecode()
        size_val = Helper.config_i64("Compress::BWTDecode", "size")
        new(size_val, UInt8[], UInt8[], BWTResult(UInt8[], 0), UInt32(0))
    end
end

function name(::BWTDecode)::String
    return "Compress::BWTDecode"
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

function prepare(b::BWTDecode)
    encoder = BWTEncode()
    encoder.size_val = b.size_val
    prepare(encoder)
    run(encoder, 0)
    b.test_data = encoder.test_data
    b.bwt_result = encoder.bwt_result
    b.result_val = 0
end

function run(b::BWTDecode, iteration_id::Int64)
    b.inverted = bwt_inverse(b.bwt_result)
    b.result_val += UInt32(length(b.inverted))
end

function checksum(b::BWTDecode)::UInt32
    res = b.result_val
    if b.inverted == b.test_data
        res += 100000
    end
    return res
end

mutable struct HuffmanNode
    frequency::Int64
    byte_val::UInt8
    is_leaf::Bool
    left::Union{HuffmanNode,Nothing}
    right::Union{HuffmanNode,Nothing}

    function HuffmanNode(freq::Int64, byte::UInt8 = 0x00, leaf::Bool = true)
        new(freq, byte, leaf, nothing, nothing)
    end
end

mutable struct HuffmanCodes
    code_lengths::Vector{Int64}
    codes::Vector{Int64}

    function HuffmanCodes()
        new(zeros(Int64, 256), zeros(Int64, 256))
    end
end

struct EncodedResult
    data::Vector{UInt8}
    bit_count::Int64
    frequencies::Vector{Int64}
end

mutable struct HuffEncode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    encoded::EncodedResult
    result_val::UInt32

    function HuffEncode()
        size_val = Helper.config_i64("Compress::HuffEncode", "size")
        new(size_val, UInt8[], EncodedResult(UInt8[], 0, zeros(Int64, 256)), UInt32(0))
    end
end

function name(::HuffEncode)::String
    return "Compress::HuffEncode"
end

function build_huffman_tree(frequencies::Vector{Int64})::HuffmanNode
    nodes = HuffmanNode[]

    for i = 1:256
        if frequencies[i] > 0
            push!(nodes, HuffmanNode(frequencies[i], UInt8(i-1), true))
        end
    end

    sort!(nodes, by = n -> n.frequency)

    if length(nodes) == 1
        node = nodes[1]
        root = HuffmanNode(node.frequency, 0x00, false)
        root.left = node
        root.right = HuffmanNode(0, 0x00, true)
        return root
    end

    while length(nodes) > 1
        left = popfirst!(nodes)
        right = popfirst!(nodes)

        parent = HuffmanNode(left.frequency + right.frequency, 0x00, false)
        parent.left = left
        parent.right = right

        pos = findfirst(n -> n.frequency >= parent.frequency, nodes)
        if pos === nothing
            push!(nodes, parent)
        else
            insert!(nodes, pos, parent)
        end
    end

    return nodes[1]
end

function build_huffman_codes(
    node::HuffmanNode,
    code::Int64,
    length::Int64,
    codes::HuffmanCodes,
)
    if node.is_leaf
        if length > 0 || node.byte_val != 0x00
            idx = Int64(node.byte_val) + 1
            codes.code_lengths[idx] = length
            codes.codes[idx] = code
        end
    else
        if node.left !== nothing
            build_huffman_codes(node.left, code << 1, length + 1, codes)
        end
        if node.right !== nothing
            build_huffman_codes(node.right, (code << 1) | 1, length + 1, codes)
        end
    end
end

function huffman_encode(
    data::Vector{UInt8},
    codes::HuffmanCodes,
    frequencies::Vector{Int64},
)::EncodedResult
    result = UInt8[]
    sizehint!(result, length(data) * 2)
    current_byte = 0x00
    bit_pos = 0
    total_bits = 0

    for byte in data
        idx = Int64(byte) + 1
        code = codes.codes[idx]
        length = codes.code_lengths[idx]

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

    return EncodedResult(result, total_bits, frequencies)
end

function prepare(b::HuffEncode)
    b.test_data = generate_test_data(b.size_val)
    b.result_val = 0
end

function run(b::HuffEncode, iteration_id::Int64)
    frequencies = zeros(Int64, 256)
    for byte in b.test_data
        frequencies[byte+1] += 1
    end

    tree = build_huffman_tree(frequencies)

    codes = HuffmanCodes()
    build_huffman_codes(tree, 0, 0, codes)

    b.encoded = huffman_encode(b.test_data, codes, frequencies)
    b.result_val += UInt32(length(b.encoded.data))
end

function checksum(b::HuffEncode)::UInt32
    return b.result_val
end

mutable struct HuffDecode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    decoded::Vector{UInt8}
    encoded::EncodedResult
    result_val::UInt32

    function HuffDecode()
        size_val = Helper.config_i64("Compress::HuffDecode", "size")
        new(
            size_val,
            UInt8[],
            UInt8[],
            EncodedResult(UInt8[], 0, zeros(Int64, 256)),
            UInt32(0),
        )
    end
end

function name(::HuffDecode)::String
    return "Compress::HuffDecode"
end

function huffman_decode(
    encoded::Vector{UInt8},
    root::HuffmanNode,
    bit_count::Int64,
)::Vector{UInt8}

    result = Vector{UInt8}(undef, bit_count)
    result_size = 0

    current_node = root
    bits_processed = 0
    byte_index = 1

    while bits_processed < bit_count && byte_index ≤ length(encoded)
        byte_val = encoded[byte_index]
        byte_index += 1

        for bit_pos = 7:-1:0
            if bits_processed ≥ bit_count
                break
            end

            bit = ((byte_val >> bit_pos) & 0x01) == 0x01
            bits_processed += 1

            current_node = bit ? current_node.right : current_node.left

            if current_node.is_leaf

                result_size += 1
                result[result_size] = current_node.byte_val

                current_node = root
            end
        end
    end

    return result[1:result_size]

end

function prepare(b::HuffDecode)
    b.test_data = generate_test_data(b.size_val)

    encoder = HuffEncode()
    encoder.size_val = b.size_val
    prepare(encoder)
    run(encoder, 0)
    b.encoded = encoder.encoded
    b.result_val = 0
end

function run(b::HuffDecode, iteration_id::Int64)
    tree = build_huffman_tree(b.encoded.frequencies)
    b.decoded = huffman_decode(b.encoded.data, tree, b.encoded.bit_count)
    b.result_val += UInt32(length(b.decoded))
end

function checksum(b::HuffDecode)::UInt32
    res = b.result_val
    if b.decoded == b.test_data
        res += 100000
    end
    return res
end

struct ArithEncodedResult
    data::Vector{UInt8}
    bit_count::Int32
    frequencies::Vector{Int64}
end

mutable struct ArithEncode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    encoded::ArithEncodedResult
    result_val::UInt32

    function ArithEncode()
        size_val = Helper.config_i64("Compress::ArithEncode", "size")
        new(size_val, UInt8[], ArithEncodedResult(UInt8[], 0, Int[]), UInt32(0))
    end
end

function name(::ArithEncode)::String
    return "Compress::ArithEncode"
end

struct ArithFreqTable
    total::Int64
    low::Vector{Int64}
    high::Vector{Int64}

    function ArithFreqTable(frequencies::Vector{Int64})
        total = Base.sum(frequencies)
        low = zeros(Int64, 256)
        high = zeros(Int64, 256)

        cum = 0
        for i = 1:256
            low[i] = cum
            cum += frequencies[i]
            high[i] = cum
        end

        new(total, low, high)
    end
end

mutable struct BitOutputStream
    buffer::UInt8
    bit_pos::Int32
    bytes::Vector{UInt8}
    bits_written::Int32

    function BitOutputStream()
        new(0x00, 0, UInt8[], 0)
    end
end

function write_bit(stream::BitOutputStream, bit::Int64)
    stream.buffer = (stream.buffer << 1) | (bit & 1)
    stream.bit_pos += 1
    stream.bits_written += 1

    if stream.bit_pos == 8
        push!(stream.bytes, stream.buffer)
        stream.buffer = 0x00
        stream.bit_pos = 0
    end
end

function flush_output(stream::BitOutputStream)::Vector{UInt8}
    if stream.bit_pos > 0
        stream.buffer <<= (8 - stream.bit_pos)
        push!(stream.bytes, stream.buffer)
    end
    return stream.bytes
end

function arith_encode(data::Vector{UInt8})::ArithEncodedResult
    frequencies = zeros(Int64, 256)
    for byte in data
        frequencies[byte+1] += 1
    end

    freq_table = ArithFreqTable(frequencies)

    low = UInt64(0)
    high = UInt64(0xFFFFFFFF)
    pending = 0
    output = BitOutputStream()

    for byte in data
        idx = Int(byte) + 1
        range = high - low + 1

        high = low + (range * UInt64(freq_table.high[idx]) ÷ UInt64(freq_table.total)) - 1
        low = low + (range * UInt64(freq_table.low[idx]) ÷ UInt64(freq_table.total))

        while true
            if high < 0x80000000
                write_bit(output, 0)
                for _ = 1:pending
                    write_bit(output, 1)
                end
                pending = 0
            elseif low >= 0x80000000
                write_bit(output, 1)
                for _ = 1:pending
                    write_bit(output, 0)
                end
                pending = 0
                low -= 0x80000000
                high -= 0x80000000
            elseif low >= 0x40000000 && high < 0xC0000000
                pending += 1
                low -= 0x40000000
                high -= 0x40000000
            else
                break
            end

            low <<= 1
            high = (high << 1) | 1
            high &= 0xFFFFFFFF
        end
    end

    pending += 1
    if low < 0x40000000
        write_bit(output, 0)
        for _ = 1:pending
            write_bit(output, 1)
        end
    else
        write_bit(output, 1)
        for _ = 1:pending
            write_bit(output, 0)
        end
    end

    return ArithEncodedResult(flush_output(output), output.bits_written, frequencies)
end

function prepare(b::ArithEncode)
    b.test_data = generate_test_data(b.size_val)
    b.result_val = 0
end

function run(b::ArithEncode, iteration_id::Int64)
    b.encoded = arith_encode(b.test_data)
    b.result_val += UInt32(length(b.encoded.data))
end

function checksum(b::ArithEncode)::UInt32
    return b.result_val
end

mutable struct ArithDecode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    decoded::Vector{UInt8}
    encoded::ArithEncodedResult
    result_val::UInt32

    function ArithDecode()
        size_val = Helper.config_i64("Compress::ArithDecode", "size")
        new(size_val, UInt8[], UInt8[], ArithEncodedResult(UInt8[], 0, Int[]), UInt32(0))
    end
end

function name(::ArithDecode)::String
    return "Compress::ArithDecode"
end

mutable struct BitInputStream
    bytes::Vector{UInt8}
    byte_pos::Int
    bit_pos::Int
    current_byte::UInt8

    function BitInputStream(bytes::Vector{UInt8})
        current = isempty(bytes) ? 0x00 : bytes[1]
        new(bytes, 1, 0, current)
    end
end

function read_bit(stream::BitInputStream)::Int
    if stream.bit_pos == 8
        stream.byte_pos += 1
        stream.bit_pos = 0
        stream.current_byte =
            stream.byte_pos <= length(stream.bytes) ? stream.bytes[stream.byte_pos] : 0x00
    end

    bit = (stream.current_byte >> (7 - stream.bit_pos)) & 1
    stream.bit_pos += 1
    return Int(bit)
end

function arith_decode(encoded::ArithEncodedResult)::Vector{UInt8}
    frequencies = encoded.frequencies
    total = Base.sum(frequencies)
    data_size = total

    low_table = zeros(Int64, 256)
    high_table = zeros(Int64, 256)
    cum = 0
    for i = 1:256
        low_table[i] = cum
        cum += frequencies[i]
        high_table[i] = cum
    end

    result = Vector{UInt8}(undef, data_size)
    input = BitInputStream(encoded.data)

    value = UInt64(0)
    for _ = 1:32
        value = (value << 1) | UInt64(read_bit(input))
    end

    low = UInt64(0)
    high = UInt64(0xFFFFFFFF)

    for j = 1:data_size
        range = high - low + 1
        scaled = ((value - low + 1) * UInt64(total) - 1) ÷ range

        symbol = 1
        while symbol < 256 && UInt64(high_table[symbol]) <= scaled
            symbol += 1
        end

        result[j] = UInt8(symbol - 1)

        high = low + (range * UInt64(high_table[symbol]) ÷ UInt64(total)) - 1
        low = low + (range * UInt64(low_table[symbol]) ÷ UInt64(total))

        while true
            if high < 0x80000000

            elseif low >= 0x80000000
                value -= 0x80000000
                low -= 0x80000000
                high -= 0x80000000
            elseif low >= 0x40000000 && high < 0xC0000000
                value -= 0x40000000
                low -= 0x40000000
                high -= 0x40000000
            else
                break
            end

            low <<= 1
            high = (high << 1) | 1
            value = (value << 1) | UInt64(read_bit(input))
        end
    end

    return result
end

function prepare(b::ArithDecode)
    b.test_data = generate_test_data(b.size_val)

    encoder = ArithEncode()
    encoder.size_val = b.size_val
    prepare(encoder)
    run(encoder, 0)
    b.encoded = encoder.encoded
    b.result_val = 0
end

function run(b::ArithDecode, iteration_id::Int64)
    b.decoded = arith_decode(b.encoded)
    b.result_val += UInt32(length(b.decoded))
end

function checksum(b::ArithDecode)::UInt32
    res = b.result_val
    if b.decoded == b.test_data
        res += 100000
    end
    return res
end

struct LZWResult
    data::Vector{UInt8}
    dict_size::Int32
end

mutable struct LZWEncode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    encoded::LZWResult
    result_val::UInt32

    function LZWEncode()
        size_val = Helper.config_i64("Compress::LZWEncode", "size")
        new(size_val, UInt8[], LZWResult(UInt8[], 256), UInt32(0))
    end
end

function name(::LZWEncode)::String
    return "Compress::LZWEncode"
end

function lzw_encode(input::Vector{UInt8})::LZWResult
    if isempty(input)
        return LZWResult(UInt8[], 256)
    end

    dict = Dict{String,Int32}()
    sizehint!(dict, 4096)
    for i = 0:255
        dict[string(Char(i))] = i
    end

    next_code = Int32(256)
    result = UInt8[]
    sizehint!(result, length(input) * 2)

    current = string(Char(input[1]))

    for i = 2:length(input)
        next_char = string(Char(input[i]))
        new_str = current * next_char

        if haskey(dict, new_str)
            current = new_str
        else
            code = dict[current]
            push!(result, UInt8((code >> 8) & 0xFF))
            push!(result, UInt8(code & 0xFF))

            dict[new_str] = next_code
            next_code += 1
            current = next_char
        end
    end

    code = dict[current]
    push!(result, UInt8((code >> 8) & 0xFF))
    push!(result, UInt8(code & 0xFF))

    return LZWResult(result, next_code)
end

function prepare(b::LZWEncode)
    b.test_data = generate_test_data(b.size_val)
    b.result_val = 0
end

function run(b::LZWEncode, iteration_id::Int64)
    b.encoded = lzw_encode(b.test_data)
    b.result_val += UInt32(length(b.encoded.data))
end

function checksum(b::LZWEncode)::UInt32
    return b.result_val
end

mutable struct LZWDecode <: AbstractBenchmark
    size_val::Int64
    test_data::Vector{UInt8}
    decoded::Vector{UInt8}
    encoded::LZWResult
    result_val::UInt32

    function LZWDecode()
        size_val = Helper.config_i64("Compress::LZWDecode", "size")
        new(size_val, UInt8[], UInt8[], LZWResult(UInt8[], 256), UInt32(0))
    end
end

function name(::LZWDecode)::String
    return "Compress::LZWDecode"
end

function lzw_decode(encoded::LZWResult)::Vector{UInt8}
    isempty(encoded.data) && return UInt8[]

    dict = String[]
    sizehint!(dict, 4096)
    for i = 0:255
        push!(dict, string(Char(i)))
    end

    result = UInt8[]
    sizehint!(result, length(encoded.data) * 2)

    data = encoded.data
    pos = 1

    old_code = (Int32(data[pos]) << 8) | Int32(data[pos+1])
    pos += 2
    old_idx = old_code + 1

    old_str = dict[old_idx]
    append!(result, codeunits(old_str))

    next_code = 256

    while pos ≤ length(data)
        new_code = (Int32(data[pos]) << 8) | Int32(data[pos+1])
        pos += 2
        new_idx = new_code + 1

        if new_code < length(dict)
            new_str = dict[new_idx]
        elseif new_code == next_code

            new_str = old_str * old_str[begin:begin]
        else
            error("LZW decode error")
        end

        append!(result, codeunits(new_str))

        push!(dict, old_str * new_str[begin:begin])
        next_code += 1

        old_code = new_code
        old_str = new_str
    end

    return result
end

function prepare(b::LZWDecode)
    b.test_data = generate_test_data(b.size_val)

    encoder = LZWEncode()
    encoder.size_val = b.size_val
    prepare(encoder)
    run(encoder, 0)
    b.encoded = encoder.encoded
    b.result_val = 0
end

function run(b::LZWDecode, iteration_id::Int64)
    b.decoded = lzw_decode(b.encoded)
    b.result_val += UInt32(length(b.decoded))
end

function checksum(b::LZWDecode)::UInt32
    res = b.result_val
    if b.decoded == b.test_data
        res += 100000
    end
    return res
end
