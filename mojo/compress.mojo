from helper import Helper
from benchmark import Benchmark, Config


def generate_test_data(size: Int) -> List[UInt8]:
    var pattern = "ABRACADABRA"
    var pattern_bytes = pattern.as_bytes()
    var data = List[UInt8](length=max(size, 0), fill=0)
    for start in range(0, size, len(pattern_bytes)):
        var count = min(len(pattern_bytes), size - start)
        data[start : start + count].copy_from(pattern_bytes[:count])
    return data^


struct BWTResult(Copyable):
    var transformed: List[UInt8]
    var original_idx: Int

    def __init__(out self):
        self.transformed = List[UInt8]()
        self.original_idx = 0

    def __init__(out self, var transformed: List[UInt8], original_idx: Int):
        self.transformed = transformed^
        self.original_idx = original_idx


struct BWTEncode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var bwt_result: BWTResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::BWTEncode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.bwt_result = BWTResult()

    def class_name(self) -> String:
        return "Compress::BWTEncode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.bwt_result = Self._bwt_transform(self.test_data)
        self.result += UInt32(len(self.bwt_result.transformed))

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def _bwt_transform(input: List[UInt8]) -> BWTResult:
        var n = len(input)
        if n == 0:
            return BWTResult()

        var counts = Array[Int, 256](fill=0)
        for i in range(n):
            counts[Int(input[i])] += 1

        var positions = Array[Int, 256](fill=0)
        var total = 0
        for i in range(256):
            positions[i] = total
            total += counts[i]

        var sa = List[Int](length=n, fill=0)
        var temp_counts = Array[Int, 256](fill=0)
        for i in range(n):
            var byte = Int(input[i])
            var pos = positions[byte] + temp_counts[byte]
            sa[pos] = i
            temp_counts[byte] += 1

        if n > 1:
            var rank = List[Int](length=n, fill=0)
            var current_rank = 0
            var prev_char = input[sa[0]]

            for i in range(n):
                var idx = sa[i]
                if input[idx] != prev_char:
                    current_rank += 1
                    prev_char = input[idx]
                rank[idx] = current_rank

            var k = 1
            while k < n:
                var pairs = List[Tuple[Int, Int]](length=n, fill=(0, 0))
                for i in range(n):
                    pairs[i] = (rank[i], rank[(i + k) % n])

                sort(
                    Span(sa),
                    lambda (a: Int, b: Int) -> Bool: (
                        pairs[a][0]
                        < pairs[b][0] if pairs[a][0]
                        != pairs[b][0] else pairs[a][1]
                        < pairs[b][1]
                    ),
                )

                var new_rank = List[Int](length=n, fill=0)
                new_rank[sa[0]] = 0
                for i in range(1, n):
                    var prev = sa[i - 1]
                    var curr = sa[i]
                    if pairs[prev] != pairs[curr]:
                        new_rank[curr] = new_rank[prev] + 1
                    else:
                        new_rank[curr] = new_rank[prev]

                rank = new_rank^
                k <<= 1

        var transformed = List[UInt8](length=n, fill=0)
        var original_idx = 0

        for i in range(n):
            var suffix = sa[i]
            if suffix == 0:
                transformed[i] = input[n - 1]
                original_idx = i
            else:
                transformed[i] = input[suffix - 1]

        return BWTResult(transformed^, original_idx)


struct BWTDecode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var inverted: List[UInt8]
    var bwt_result: BWTResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::BWTDecode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.inverted = List[UInt8]()
        self.bwt_result = BWTResult()

    def class_name(self) -> String:
        return "Compress::BWTDecode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)
        self.bwt_result = BWTEncode._bwt_transform(self.test_data)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.inverted = Self._bwt_inverse(self.bwt_result)
        self.result += UInt32(len(self.inverted))

    def checksum(mut self) -> UInt32:
        if len(self.inverted) == len(self.test_data):
            var equal = True
            for i in range(len(self.test_data)):
                if self.inverted[i] != self.test_data[i]:
                    equal = False
                    break
            if equal:
                self.result += 100000
        return self.result

    @staticmethod
    def _bwt_inverse(bwt_result: BWTResult) -> List[UInt8]:
        ref bwt = bwt_result.transformed
        var n = len(bwt)
        if n == 0:
            return List[UInt8]()

        var counts = Array[Int, 256](fill=0)
        for i in range(n):
            counts[Int(bwt[i])] += 1

        var positions = Array[Int, 256](fill=0)
        var total = 0
        for i in range(256):
            positions[i] = total
            total += counts[i]

        var next_arr = List[Int](length=n, fill=0)
        var temp_counts = Array[Int, 256](fill=0)

        for i in range(n):
            var byte = Int(bwt[i])
            var pos = positions[byte] + temp_counts[byte]
            next_arr[pos] = i
            temp_counts[byte] += 1

        var result = List[UInt8](length=n, fill=0)
        var idx = bwt_result.original_idx

        for i in range(n):
            idx = next_arr[idx]
            result[i] = bwt[idx]

        return result^


struct _HuffmanNode(Copyable, ImplicitlyCopyable):
    var frequency: Int
    var byte_val: UInt8
    var is_leaf: Bool
    var left: Int
    var right: Int

    def __init__(out self, frequency: Int, byte_val: UInt8, is_leaf: Bool):
        self.frequency = frequency
        self.byte_val = byte_val
        self.is_leaf = is_leaf
        self.left = -1
        self.right = -1


struct _HuffmanCodes(Copyable):
    var code_lengths: Array[Int, 256]
    var codes: Array[Int, 256]

    def __init__(out self):
        self.code_lengths = Array[Int, 256](fill=0)
        self.codes = Array[Int, 256](fill=0)


struct _HuffEncodedResult(Copyable):
    var frequencies: Array[Int, 256]
    var data: List[UInt8]
    var bit_count: Int

    def __init__(out self):
        self.frequencies = Array[Int, 256](fill=0)
        self.data = List[UInt8]()
        self.bit_count = 0

    def __init__(
        out self,
        var data: List[UInt8],
        bit_count: Int,
        var frequencies: Array[Int, 256],
    ):
        self.data = data^
        self.bit_count = bit_count
        self.frequencies = frequencies^


def _build_huffman_tree_nodes(
    frequencies: Array[Int, 256],
) -> Tuple[List[_HuffmanNode], Int]:
    var nodes = List[_HuffmanNode]()
    var heap = List[Int]()

    for i in range(256):
        if frequencies[i] > 0:
            nodes.append(_HuffmanNode(frequencies[i], UInt8(i), True))
            heap.append(len(nodes) - 1)

    sort(
        Span(heap),
        lambda (a: Int, b: Int) -> Bool: nodes[a].frequency
        < nodes[b].frequency,
    )

    if len(heap) == 1:
        var leaf_idx = heap[0]
        nodes.append(_HuffmanNode(nodes[leaf_idx].frequency, 0, False))
        var root_idx = len(nodes) - 1
        nodes[root_idx].left = leaf_idx
        nodes.append(_HuffmanNode(0, 0, True))
        nodes[root_idx].right = len(nodes) - 1
        return (nodes^, root_idx)

    while len(heap) > 1:
        var left_idx = heap[0]
        _ = heap.pop(0)
        var right_idx = heap[0]
        _ = heap.pop(0)

        nodes.append(
            _HuffmanNode(
                nodes[left_idx].frequency + nodes[right_idx].frequency, 0, False
            )
        )
        var parent_idx = len(nodes) - 1
        nodes[parent_idx].left = left_idx
        nodes[parent_idx].right = right_idx

        var lo = 0
        var hi = len(heap)
        while lo < hi:
            var mid = (lo + hi) // 2
            if nodes[heap[mid]].frequency < nodes[parent_idx].frequency:
                lo = mid + 1
            else:
                hi = mid
        heap.insert(lo, parent_idx)

    return (nodes^, heap[0])


def _build_huffman_codes(
    ref nodes: List[_HuffmanNode],
    node_idx: Int,
    code: Int,
    length: Int,
    mut codes: _HuffmanCodes,
):
    var node = nodes[node_idx]
    if node.is_leaf:
        if length > 0 or node.byte_val != 0:
            var idx = Int(node.byte_val)
            codes.code_lengths[idx] = length
            codes.codes[idx] = code
    else:
        if node.left >= 0:
            _build_huffman_codes(nodes, node.left, code << 1, length + 1, codes)
        if node.right >= 0:
            _build_huffman_codes(
                nodes, node.right, (code << 1) | 1, length + 1, codes
            )


def _huffman_encode(
    data: List[UInt8],
    codes: _HuffmanCodes,
    var frequencies: Array[Int, 256],
) -> _HuffEncodedResult:
    var result = List[UInt8]()
    var current_byte: UInt8 = 0
    var bit_pos: Int = 0
    var total_bits: Int = 0

    for i in range(len(data)):
        var byte = Int(data[i])
        var code = codes.codes[byte]
        var length = codes.code_lengths[byte]

        for j in range(length):
            var bit_idx = length - 1 - j
            if (code & (1 << bit_idx)) != 0:
                current_byte |= UInt8(1 << (7 - bit_pos))
            bit_pos += 1
            total_bits += 1

            if bit_pos == 8:
                result.append(current_byte)
                current_byte = 0
                bit_pos = 0

    if bit_pos > 0:
        result.append(current_byte)

    return _HuffEncodedResult(result^, total_bits, frequencies^)


def _huffman_decode(
    ref nodes: List[_HuffmanNode],
    root_idx: Int,
    encoded: List[UInt8],
    bit_count: Int,
) -> List[UInt8]:
    var result = List[UInt8]()
    var current_idx = root_idx
    var bits_processed = 0
    var byte_idx = 0

    while bits_processed < bit_count and byte_idx < len(encoded):
        var byte_val = encoded[byte_idx]
        byte_idx += 1

        for bit_pos in range(7, -1, -1):
            if bits_processed >= bit_count:
                break
            var bit = ((Int(byte_val) >> bit_pos) & 1) == 1
            bits_processed += 1

            var node = nodes[current_idx]
            if bit:
                current_idx = node.right
            else:
                current_idx = node.left

            if nodes[current_idx].is_leaf:
                result.append(nodes[current_idx].byte_val)
                current_idx = root_idx

    return result^


struct HuffEncode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var encoded: _HuffEncodedResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::HuffEncode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.encoded = _HuffEncodedResult()

    def class_name(self) -> String:
        return "Compress::HuffEncode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var frequencies = Array[Int, 256](fill=0)
        for i in range(len(self.test_data)):
            frequencies[Int(self.test_data[i])] += 1

        var tree_result = _build_huffman_tree_nodes(frequencies)
        ref nodes = tree_result[0]
        var root_idx = tree_result[1]

        var codes = _HuffmanCodes()
        _build_huffman_codes(nodes, root_idx, 0, 0, codes)

        self.encoded = _huffman_encode(self.test_data, codes, frequencies^)
        self.result += UInt32(len(self.encoded.data))

    def checksum(self) -> UInt32:
        return self.result


struct HuffDecode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var decoded: List[UInt8]
    var encoded: _HuffEncodedResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::HuffDecode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.decoded = List[UInt8]()
        self.encoded = _HuffEncodedResult()

    def class_name(self) -> String:
        return "Compress::HuffDecode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

        var frequencies = Array[Int, 256](fill=0)
        for i in range(len(self.test_data)):
            frequencies[Int(self.test_data[i])] += 1

        var tree_result = _build_huffman_tree_nodes(frequencies)
        ref nodes = tree_result[0]
        var root_idx = tree_result[1]

        var codes = _HuffmanCodes()
        _build_huffman_codes(nodes, root_idx, 0, 0, codes)

        self.encoded = _huffman_encode(self.test_data, codes, frequencies^)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        ref frequencies = self.encoded.frequencies
        ref data = self.encoded.data
        var bit_count = self.encoded.bit_count

        var tree_result = _build_huffman_tree_nodes(frequencies)
        ref nodes = tree_result[0]
        var root_idx = tree_result[1]

        self.decoded = _huffman_decode(nodes, root_idx, data, bit_count)
        self.result += UInt32(len(self.decoded))

    def checksum(self) -> UInt32:
        var r = self.result
        if len(self.decoded) == len(self.test_data):
            var equal = True
            for i in range(len(self.test_data)):
                if self.decoded[i] != self.test_data[i]:
                    equal = False
                    break
            if equal:
                r += 100000
        return r


struct _ArithFreqTable(Copyable):
    var total: Int
    var low: Array[Int, 256]
    var high: Array[Int, 256]

    def __init__(out self, frequencies: Array[Int, 256]):
        self.total = 0
        for i in range(256):
            self.total += frequencies[i]
        self.low = Array[Int, 256](fill=0)
        self.high = Array[Int, 256](fill=0)

        var cum = 0
        for i in range(256):
            self.low[i] = cum
            cum += frequencies[i]
            self.high[i] = cum


struct _ArithEncodedResult(Copyable):
    var data: List[UInt8]
    var frequencies: Array[Int, 256]

    def __init__(out self):
        self.data = List[UInt8]()
        self.frequencies = Array[Int, 256](fill=0)

    def __init__(
        out self, var data: List[UInt8], var frequencies: Array[Int, 256]
    ):
        self.data = data^
        self.frequencies = frequencies^


struct _BitOutputStream:
    var buffer: UInt8
    var bit_pos: Int
    var bytes: List[UInt8]
    var bits_written: Int

    def __init__(out self):
        self.buffer = 0
        self.bit_pos = 0
        self.bytes = List[UInt8]()
        self.bits_written = 0

    def write_bit(mut self, bit: Int):
        self.buffer = (self.buffer << 1) | UInt8(bit & 1)
        self.bit_pos += 1
        self.bits_written += 1

        if self.bit_pos == 8:
            self.bytes.append(self.buffer)
            self.buffer = 0
            self.bit_pos = 0

    def flush(mut self) -> List[UInt8]:
        if self.bit_pos > 0:
            self.buffer <<= UInt8(8 - self.bit_pos)
            self.bytes.append(self.buffer)
        var result = self.bytes^
        self.bytes = List[UInt8]()
        return result^


struct _BitInputStream[origin: Origin]:
    var bytes: Span[UInt8, Self.origin]
    var byte_pos: Int
    var bit_pos: Int
    var current_byte: UInt8

    def __init__(out self, bytes: Span[UInt8, Self.origin]):
        self.bytes = bytes
        self.byte_pos = 0
        self.bit_pos = 0
        self.current_byte = 0
        if len(self.bytes) > 0:
            self.current_byte = self.bytes[0]

    def read_bit(mut self) -> Int:
        if self.bit_pos == 8:
            self.byte_pos += 1
            self.bit_pos = 0
            if self.byte_pos < len(self.bytes):
                self.current_byte = self.bytes[self.byte_pos]
            else:
                self.current_byte = 0

        var bit = (Int(self.current_byte) >> (7 - self.bit_pos)) & 1
        self.bit_pos += 1
        return bit


def _arith_encode_data(data: List[UInt8]) -> _ArithEncodedResult:
    var frequencies = Array[Int, 256](fill=0)
    for i in range(len(data)):
        frequencies[Int(data[i])] += 1

    var freq_table = _ArithFreqTable(frequencies)

    var low: UInt64 = 0
    var high: UInt64 = 0xFFFFFFFF
    var pend: Int = 0
    var output = _BitOutputStream()

    for i in range(len(data)):
        var byte = Int(data[i])
        var rng = high - low + 1

        high = (
            low
            + (rng * UInt64(freq_table.high[byte]) // UInt64(freq_table.total))
            - 1
        )
        low = low + (
            rng * UInt64(freq_table.low[byte]) // UInt64(freq_table.total)
        )

        while True:
            if high < 0x80000000:
                output.write_bit(0)
                for _ in range(pend):
                    output.write_bit(1)
                pend = 0
            elif low >= 0x80000000:
                output.write_bit(1)
                for _ in range(pend):
                    output.write_bit(0)
                pend = 0
                low -= 0x80000000
                high -= 0x80000000
            elif low >= 0x40000000 and high < 0xC0000000:
                pend += 1
                low -= 0x40000000
                high -= 0x40000000
            else:
                break

            low <<= 1
            high = (high << 1) | 1
            high &= 0xFFFFFFFF

    pend += 1
    if low < 0x40000000:
        output.write_bit(0)
        for _ in range(pend):
            output.write_bit(1)
    else:
        output.write_bit(1)
        for _ in range(pend):
            output.write_bit(0)

    var result_data = output.flush()
    return _ArithEncodedResult(result_data^, frequencies^)


def _arith_decode_data(encoded: _ArithEncodedResult) -> List[UInt8]:
    ref frequencies = encoded.frequencies
    ref data = encoded.data

    var total = 0
    for i in range(256):
        total += frequencies[i]
    var data_size = total

    var freq_table = _ArithFreqTable(frequencies)

    var result = List[UInt8](length=data_size, fill=0)
    var input = _BitInputStream(Span(data))

    var value: UInt64 = 0
    for _ in range(32):
        value = (value << 1) | UInt64(input.read_bit())

    var low: UInt64 = 0
    var high: UInt64 = 0xFFFFFFFF

    for j in range(data_size):
        var rng = high - low + 1
        var scaled = ((value - low + 1) * UInt64(total) - 1) // rng

        var left: Int = 0
        var right: Int = 256
        while left < right:
            var mid = (left + right) // 2
            if UInt64(freq_table.high[mid]) <= scaled:
                left = mid + 1
            else:
                right = mid
        var symbol: UInt8 = UInt8(left)

        result[j] = symbol

        high = (
            low
            + (rng * UInt64(freq_table.high[Int(symbol)]) // UInt64(total))
            - 1
        )
        low = low + (rng * UInt64(freq_table.low[Int(symbol)]) // UInt64(total))

        while True:
            if high < 0x80000000:
                pass
            elif low >= 0x80000000:
                value -= 0x80000000
                low -= 0x80000000
                high -= 0x80000000
            elif low >= 0x40000000 and high < 0xC0000000:
                value -= 0x40000000
                low -= 0x40000000
                high -= 0x40000000
            else:
                break
            low <<= 1
            high = (high << 1) | 1
            value = (value << 1) | UInt64(input.read_bit())

    return result^


struct ArithEncode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var encoded: _ArithEncodedResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::ArithEncode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.encoded = _ArithEncodedResult()

    def class_name(self) -> String:
        return "Compress::ArithEncode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.encoded = _arith_encode_data(self.test_data)
        self.result += UInt32(len(self.encoded.data))

    def checksum(self) -> UInt32:
        return self.result


struct ArithDecode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var decoded: List[UInt8]
    var encoded: _ArithEncodedResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::ArithDecode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.decoded = List[UInt8]()
        self.encoded = _ArithEncodedResult()

    def class_name(self) -> String:
        return "Compress::ArithDecode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

        self.encoded = _arith_encode_data(self.test_data)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.decoded = _arith_decode_data(self.encoded)
        self.result += UInt32(len(self.decoded))

    def checksum(self) -> UInt32:
        var r = self.result
        if len(self.decoded) == len(self.test_data):
            var equal = True
            for i in range(len(self.test_data)):
                if self.decoded[i] != self.test_data[i]:
                    equal = False
                    break
            if equal:
                r += 100000
        return r


struct _LZWResult(Copyable):
    var data: List[UInt8]
    var dict_size: Int

    def __init__(out self):
        self.data = List[UInt8]()
        self.dict_size = 256

    def __init__(out self, var data: List[UInt8], dict_size: Int):
        self.data = data^
        self.dict_size = dict_size


struct LZWEncode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var encoded: _LZWResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::LZWEncode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.encoded = _LZWResult()

    def class_name(self) -> String:
        return "Compress::LZWEncode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.encoded = Self._lzw_encode(self.test_data)
        self.result += UInt32(len(self.encoded.data))

    def checksum(self) -> UInt32:
        return self.result

    @staticmethod
    def _lzw_encode(input: List[UInt8]) raises -> _LZWResult:
        var n = len(input)
        if n == 0:
            return _LZWResult()

        var dict = Dict[String, Int]()
        for i in range(256):
            dict[String(chr(i))] = i

        var next_code = 256
        var result = List[UInt8]()

        var current = String(chr(Int(input[0])))

        for i in range(1, n):
            var next_char = String(chr(Int(input[i])))
            var new_str = current + next_char

            if new_str in dict:
                current = new_str
            else:
                var code = dict[current]
                result.append(UInt8((code >> 8) & 0xFF))
                result.append(UInt8(code & 0xFF))

                dict[new_str] = next_code
                next_code += 1
                current = next_char

        var code = dict[current]
        result.append(UInt8((code >> 8) & 0xFF))
        result.append(UInt8(code & 0xFF))

        return _LZWResult(result^, next_code)


struct LZWDecode(Benchmark):
    var size: Int
    var result: UInt32
    var test_data: List[UInt8]
    var decoded: List[UInt8]
    var encoded: _LZWResult

    def __init__(out self, config: Config) raises:
        self.size = config.get_i64("Compress::LZWDecode", "size")
        self.result = 0
        self.test_data = List[UInt8]()
        self.decoded = List[UInt8]()
        self.encoded = _LZWResult()

    def class_name(self) -> String:
        return "Compress::LZWDecode"

    def prepare(mut self, mut helper: Helper) raises:
        self.test_data = generate_test_data(self.size)
        self.encoded = LZWEncode._lzw_encode(self.test_data)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        self.decoded = Self._lzw_decode(self.encoded)
        self.result += UInt32(len(self.decoded))

    def checksum(self) -> UInt32:
        var r = self.result
        if len(self.decoded) == len(self.test_data):
            var equal = True
            for i in range(len(self.test_data)):
                if self.decoded[i] != self.test_data[i]:
                    equal = False
                    break
            if equal:
                r += 100000
        return r

    @staticmethod
    def _lzw_decode(encoded: _LZWResult) -> List[UInt8]:
        ref data = encoded.data
        if len(data) == 0:
            return List[UInt8]()

        var dict = List[String](capacity=4096)
        for i in range(256):
            dict.append(String(chr(i)))

        var result = List[UInt8]()
        var pos = 0

        var high = Int(data[pos])
        var low = Int(data[pos + 1])
        var old_code = (high << 8) | low
        pos += 2

        var old_str = dict[old_code]
        result.extend(old_str.as_bytes())

        var next_code = 256

        while pos < len(data):
            high = Int(data[pos])
            low = Int(data[pos + 1])
            var new_code = (high << 8) | low
            pos += 2

            var new_str: String
            if new_code < len(dict):
                new_str = dict[new_code]
            elif new_code == next_code:
                new_str = old_str + String(old_str[byte=0])
            else:
                return List[UInt8]()

            result.extend(new_str.as_bytes())

            dict.append(old_str + String(new_str[byte=0]))
            next_code += 1

            old_str = new_str

        return result^
