use super::super::Benchmark;
use crate::config_i64;
use std::collections::HashMap;

fn generate_test_data(size: i64) -> Vec<u8> {
    let pattern = b"ABRACADABRA";
    let pattern_len = pattern.len();
    let mut data = Vec::with_capacity(size as usize);

    for i in 0..size {
        data.push(pattern[(i as usize) % pattern_len]);
    }

    data
}

#[derive(Debug, Clone, PartialEq)]
struct BWTResult {
    transformed: Vec<u8>,
    original_idx: i32,
}

impl BWTResult {
    fn new(transformed: Vec<u8>, original_idx: i32) -> Self {
        Self {
            transformed,
            original_idx,
        }
    }
}

fn bwt_transform(input: &[u8]) -> BWTResult {
    let n = input.len();
    if n == 0 {
        return BWTResult::new(Vec::new(), 0);
    }

    let mut counts = [0; 256];
    for &byte in input {
        counts[byte as usize] += 1;
    }

    let mut positions = [0; 256];
    let mut total = 0;
    for i in 0..256 {
        positions[i] = total;
        total += counts[i];
    }

    let mut sa = vec![0; n];
    let mut temp_counts = [0; 256];
    for i in 0..n {
        let byte = input[i] as usize;
        let pos = positions[byte] + temp_counts[byte];
        sa[pos] = i;
        temp_counts[byte] += 1;
    }

    if n > 1 {
        let mut rank = vec![0; n];
        let mut current_rank = 0;
        let mut prev_char = input[sa[0]];

        for i in 0..n {
            let idx = sa[i];
            if input[idx] != prev_char {
                current_rank += 1;
                prev_char = input[idx];
            }
            rank[idx] = current_rank;
        }

        let mut k = 1;
        while k < n {
            sa.sort_by(|&a, &b| {
                let ra = rank[a];
                let rb = rank[b];
                if ra != rb {
                    ra.cmp(&rb)
                } else {
                    let rak = rank[(a + k) % n];
                    let rbk = rank[(b + k) % n];
                    rak.cmp(&rbk)
                }
            });

            let mut new_rank = vec![0; n];
            new_rank[sa[0]] = 0;
            for i in 1..n {
                let prev = sa[i - 1];
                let curr = sa[i];
                new_rank[curr] = new_rank[prev]
                    + if rank[prev] != rank[curr] || rank[(prev + k) % n] != rank[(curr + k) % n] {
                        1
                    } else {
                        0
                    };
            }

            rank = new_rank;
            k <<= 1;
        }
    }

    let mut transformed = vec![0; n];
    let mut original_idx = 0;

    for (i, &suffix) in sa.iter().enumerate() {
        if suffix == 0 {
            transformed[i] = input[n - 1];
            original_idx = i as i32;
        } else {
            transformed[i] = input[suffix - 1];
        }
    }

    BWTResult::new(transformed, original_idx)
}

pub struct BWTEncode {
    size_val: i64,
    test_data: Vec<u8>,
    bwt_result: BWTResult,
    result_val: u32,
}

impl BWTEncode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::BWTEncode", "size");
        Self {
            size_val,
            test_data: Vec::new(),
            bwt_result: BWTResult::new(Vec::new(), 0),
            result_val: 0,
        }
    }
}

impl Benchmark for BWTEncode {
    fn name(&self) -> String {
        "Compress::BWTEncode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);
    }

    fn run(&mut self, _iteration_id: i64) {
        self.bwt_result = bwt_transform(&self.test_data);
        self.result_val = self
            .result_val
            .wrapping_add(self.bwt_result.transformed.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

fn bwt_inverse(bwt_result: &BWTResult) -> Vec<u8> {
    let bwt = &bwt_result.transformed;
    let n = bwt.len();
    if n == 0 {
        return Vec::new();
    }

    let mut counts = [0i32; 256];
    for &byte in bwt {
        counts[byte as usize] += 1;
    }

    let mut positions = [0i32; 256];
    let mut total = 0;
    for i in 0..256 {
        positions[i] = total;
        total += counts[i];
    }

    let mut next = vec![0usize; n];
    let mut temp_counts = [0i32; 256];

    for (i, &byte) in bwt.iter().enumerate() {
        let byte_idx = byte as usize;
        let pos = (positions[byte_idx] + temp_counts[byte_idx]) as usize;
        next[pos] = i;
        temp_counts[byte_idx] += 1;
    }

    let mut result = vec![0u8; n];
    let mut idx = bwt_result.original_idx as usize;

    for i in 0..n {
        idx = next[idx];
        result[i] = bwt[idx];
    }

    result
}

pub struct BWTDecode {
    size_val: i64,
    test_data: Vec<u8>,
    inverted: Vec<u8>,
    bwt_result: BWTResult,
    result_val: u32,
}

impl BWTDecode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::BWTDecode", "size");
        Self {
            size_val,
            test_data: Vec::new(),
            inverted: Vec::new(),
            bwt_result: BWTResult::new(Vec::new(), 0),
            result_val: 0,
        }
    }
}

impl Benchmark for BWTDecode {
    fn name(&self) -> String {
        "Compress::BWTDecode".to_string()
    }

    fn prepare(&mut self) {
        let mut encoder = BWTEncode::new();
        encoder.size_val = self.size_val;
        encoder.prepare();
        encoder.run(0);
        self.test_data = encoder.test_data.clone();
        self.bwt_result = encoder.bwt_result;
    }

    fn run(&mut self, _iteration_id: i64) {
        self.inverted = bwt_inverse(&self.bwt_result);
        self.result_val = self.result_val.wrapping_add(self.inverted.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let mut res = self.result_val;
        if self.inverted == self.test_data {
            res = res.wrapping_add(100000);
        }
        res
    }
}

struct HuffmanNode {
    frequency: i32,
    byte_val: u8,
    is_leaf: bool,
    left: Option<Box<HuffmanNode>>,
    right: Option<Box<HuffmanNode>>,
}

impl HuffmanNode {
    fn new(freq: i32, byte: u8, leaf: bool) -> Self {
        Self {
            frequency: freq,
            byte_val: byte,
            is_leaf: leaf,
            left: None,
            right: None,
        }
    }
}

struct HuffmanCodes {
    code_lengths: Vec<i32>,
    codes: Vec<i32>,
}

impl HuffmanCodes {
    fn new() -> Self {
        Self {
            code_lengths: vec![0; 256],
            codes: vec![0; 256],
        }
    }
}

struct EncodedResult {
    data: Vec<u8>,
    bit_count: i32,
    frequencies: Vec<i32>,
}

impl EncodedResult {
    fn new(data: Vec<u8>, bit_count: i32, frequencies: Vec<i32>) -> Self {
        Self {
            data,
            bit_count,
            frequencies,
        }
    }
}

fn build_huffman_tree(frequencies: &[i32]) -> Option<Box<HuffmanNode>> {
    let mut nodes: Vec<Box<HuffmanNode>> = frequencies
        .iter()
        .enumerate()
        .filter(|(_, &freq)| freq > 0)
        .map(|(i, &freq)| Box::new(HuffmanNode::new(freq, i as u8, true)))
        .collect();

    nodes.sort_by(|a, b| a.frequency.cmp(&b.frequency));

    if nodes.len() == 1 {
        let node = nodes.remove(0);
        let mut root = Box::new(HuffmanNode::new(node.frequency, 0, false));
        root.left = Some(node);
        root.right = Some(Box::new(HuffmanNode::new(0, 0, true)));
        return Some(root);
    }

    while nodes.len() > 1 {
        let left = nodes.remove(0);
        let right = nodes.remove(0);

        let mut parent = Box::new(HuffmanNode::new(left.frequency + right.frequency, 0, false));
        parent.left = Some(left);
        parent.right = Some(right);

        let pos = nodes
            .binary_search_by(|n| n.frequency.cmp(&parent.frequency))
            .unwrap_or_else(|e| e);
        nodes.insert(pos, parent);
    }

    nodes.pop()
}

fn build_huffman_codes(
    node: &HuffmanNode,
    code: i32,
    length: i32,
    huffman_codes: &mut HuffmanCodes,
) {
    if node.is_leaf {
        if length > 0 || node.byte_val != 0 {
            let idx = node.byte_val as usize;
            huffman_codes.code_lengths[idx] = length;
            huffman_codes.codes[idx] = code;
        }
    } else {
        if let Some(ref left) = node.left {
            build_huffman_codes(left, code << 1, length + 1, huffman_codes);
        }
        if let Some(ref right) = node.right {
            build_huffman_codes(right, (code << 1) | 1, length + 1, huffman_codes);
        }
    }
}

fn huffman_encode(data: &[u8], codes: &HuffmanCodes, frequencies: Vec<i32>) -> EncodedResult {
    let mut result = Vec::with_capacity(data.len() * 2);
    let mut current_byte = 0u8;
    let mut bit_pos = 0;
    let mut total_bits = 0;

    for &byte in data {
        let idx = byte as usize;
        let code = codes.codes[idx];
        let length = codes.code_lengths[idx] as usize;

        for i in (0..length).rev() {
            if (code & (1 << i)) != 0 {
                current_byte |= 1 << (7 - bit_pos);
            }
            bit_pos += 1;
            total_bits += 1;

            if bit_pos == 8 {
                result.push(current_byte);
                current_byte = 0;
                bit_pos = 0;
            }
        }
    }

    if bit_pos > 0 {
        result.push(current_byte);
    }

    EncodedResult::new(result, total_bits, frequencies)
}

pub struct HuffEncode {
    size_val: i64,
    test_data: Vec<u8>,
    encoded: EncodedResult,
    result_val: u32,
}

impl HuffEncode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::HuffEncode", "size");
        Self {
            size_val,
            test_data: Vec::new(),
            encoded: EncodedResult::new(Vec::new(), 0, Vec::new()),
            result_val: 0,
        }
    }
}

impl Benchmark for HuffEncode {
    fn name(&self) -> String {
        "Compress::HuffEncode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut frequencies = vec![0; 256];
        for &byte in &self.test_data {
            frequencies[byte as usize] += 1;
        }

        let tree = build_huffman_tree(&frequencies);

        let mut codes = HuffmanCodes::new();
        if let Some(ref tree) = tree {
            build_huffman_codes(tree, 0, 0, &mut codes);
        }

        self.encoded = huffman_encode(&self.test_data, &codes, frequencies);
        self.result_val = self.result_val.wrapping_add(self.encoded.data.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

fn huffman_decode(encoded: &[u8], root: &HuffmanNode, bit_count: i32) -> Vec<u8> {
    let mut result = vec![0u8; bit_count as usize];
    let mut result_size = 0;

    let mut current_node = root;
    let mut bits_processed = 0;
    let mut byte_index = 0;

    while bits_processed < bit_count && byte_index < encoded.len() {
        let byte_val = encoded[byte_index];
        byte_index += 1;

        for bit_pos in (0..8).rev() {
            if bits_processed >= bit_count {
                break;
            }

            let bit = ((byte_val >> bit_pos) & 1) == 1;
            bits_processed += 1;

            current_node = if bit {
                current_node.right.as_ref().unwrap()
            } else {
                current_node.left.as_ref().unwrap()
            };

            if current_node.is_leaf {
                if current_node.byte_val != 0 {
                    result[result_size] = current_node.byte_val;
                    result_size += 1;
                }
                current_node = root;
            }
        }
    }

    result.truncate(result_size);
    result
}

pub struct HuffDecode {
    size_val: i64,
    test_data: Vec<u8>,
    decoded: Vec<u8>,
    encoded: EncodedResult,
    result_val: u32,
}

impl HuffDecode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::HuffDecode", "size");
        Self {
            size_val,
            test_data: Vec::new(),
            decoded: Vec::new(),
            encoded: EncodedResult::new(Vec::new(), 0, Vec::new()),
            result_val: 0,
        }
    }
}

impl Benchmark for HuffDecode {
    fn name(&self) -> String {
        "Compress::HuffDecode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);

        let mut encoder = HuffEncode::new();
        encoder.size_val = self.size_val;
        encoder.prepare();
        encoder.run(0);
        self.encoded = encoder.encoded;
    }

    fn run(&mut self, _iteration_id: i64) {
        let tree = build_huffman_tree(&self.encoded.frequencies);
        if let Some(ref tree) = tree {
            self.decoded = huffman_decode(&self.encoded.data, tree, self.encoded.bit_count);
            self.result_val = self.result_val.wrapping_add(self.decoded.len() as u32);
        }
    }

    fn checksum(&self) -> u32 {
        let mut res = self.result_val;
        if self.decoded == self.test_data {
            res = res.wrapping_add(100000);
        }
        res
    }
}

pub struct ArithEncode {
    size_val: i64,
    result_val: u32,
    test_data: Vec<u8>,
    encoded: ArithEncodedResult,
}

#[derive(Default)]
pub struct ArithEncodedResult {
    data: Vec<u8>,
    bit_count: i32,
    frequencies: Vec<i32>,
}

impl ArithEncodedResult {
    fn new() -> Self {
        Self {
            data: Vec::new(),
            bit_count: 0,
            frequencies: Vec::new(),
        }
    }
}

struct ArithFreqTable {
    total: i32,
    low: Vec<i32>,
    high: Vec<i32>,
}

impl ArithFreqTable {
    fn new(frequencies: &[i32]) -> Self {
        let total: i32 = frequencies.iter().sum();
        let mut low = vec![0; 256];
        let mut high = vec![0; 256];

        let mut cum = 0;
        for i in 0..256 {
            low[i] = cum;
            cum += frequencies[i];
            high[i] = cum;
        }

        Self { total, low, high }
    }
}

struct BitOutputStream {
    buffer: u8,
    bit_pos: i32,
    bytes: Vec<u8>,
    bits_written: i32,
}

impl BitOutputStream {
    fn new() -> Self {
        Self {
            buffer: 0,
            bit_pos: 0,
            bytes: Vec::new(),
            bits_written: 0,
        }
    }

    fn write_bit(&mut self, bit: i32) {
        self.buffer = (self.buffer << 1) | (bit as u8 & 1);
        self.bit_pos += 1;
        self.bits_written += 1;

        if self.bit_pos == 8 {
            self.bytes.push(self.buffer);
            self.buffer = 0;
            self.bit_pos = 0;
        }
    }

    fn flush(&mut self) -> Vec<u8> {
        if self.bit_pos > 0 {
            self.buffer <<= 8 - self.bit_pos;
            self.bytes.push(self.buffer);
        }
        std::mem::take(&mut self.bytes)
    }

    fn bits_written(&self) -> i32 {
        self.bits_written
    }
}

impl ArithEncode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::ArithEncode", "size");
        Self {
            size_val,
            result_val: 0,
            test_data: Vec::new(),
            encoded: ArithEncodedResult::new(),
        }
    }
}

fn arith_encode(data: &[u8]) -> ArithEncodedResult {
    let mut frequencies = vec![0; 256];
    for &byte in data {
        frequencies[byte as usize] += 1;
    }

    let freq_table = ArithFreqTable::new(&frequencies);

    let mut low = 0u64;
    let mut high = 0xFFFFFFFFu64;
    let mut pending = 0;
    let mut output = BitOutputStream::new();

    for &byte in data {
        let idx = byte as usize;
        let range = high - low + 1;

        high = low + (range * freq_table.high[idx] as u64 / freq_table.total as u64) - 1;
        low = low + (range * freq_table.low[idx] as u64 / freq_table.total as u64);

        loop {
            if high < 0x80000000 {
                output.write_bit(0);
                for _ in 0..pending {
                    output.write_bit(1);
                }
                pending = 0;
            } else if low >= 0x80000000 {
                output.write_bit(1);
                for _ in 0..pending {
                    output.write_bit(0);
                }
                pending = 0;
                low -= 0x80000000;
                high -= 0x80000000;
            } else if low >= 0x40000000 && high < 0xC0000000 {
                pending += 1;
                low -= 0x40000000;
                high -= 0x40000000;
            } else {
                break;
            }

            low <<= 1;
            high = (high << 1) | 1;
            high &= 0xFFFFFFFF;
        }
    }

    pending += 1;
    if low < 0x40000000 {
        output.write_bit(0);
        for _ in 0..pending {
            output.write_bit(1);
        }
    } else {
        output.write_bit(1);
        for _ in 0..pending {
            output.write_bit(0);
        }
    }

    ArithEncodedResult {
        data: output.flush(),
        bit_count: output.bits_written(),
        frequencies,
    }
}

impl Benchmark for ArithEncode {
    fn name(&self) -> String {
        "Compress::ArithEncode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);
    }

    fn run(&mut self, _iteration_id: i64) {
        self.encoded = arith_encode(&self.test_data);
        self.result_val = self.result_val.wrapping_add(self.encoded.data.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

pub struct ArithDecode {
    size_val: i64,
    result_val: u32,
    test_data: Vec<u8>,
    decoded: Vec<u8>,
    encoded: ArithEncodedResult,
}

struct BitInputStream<'a> {
    bytes: &'a [u8],
    byte_pos: usize,
    bit_pos: i32,
    current_byte: u8,
}

impl<'a> BitInputStream<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self {
            bytes,
            byte_pos: 0,
            bit_pos: 0,
            current_byte: if !bytes.is_empty() { bytes[0] } else { 0 },
        }
    }

    fn read_bit(&mut self) -> i32 {
        if self.bit_pos == 8 {
            self.byte_pos += 1;
            self.bit_pos = 0;
            self.current_byte = if self.byte_pos < self.bytes.len() {
                self.bytes[self.byte_pos]
            } else {
                0
            };
        }

        let bit = ((self.current_byte >> (7 - self.bit_pos)) & 1) as i32;
        self.bit_pos += 1;
        bit
    }
}

impl ArithDecode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::ArithDecode", "size");
        Self {
            size_val,
            result_val: 0,
            test_data: Vec::new(),
            decoded: Vec::new(),
            encoded: ArithEncodedResult::new(),
        }
    }
}

fn arith_decode(encoded: &ArithEncodedResult) -> Vec<u8> {
    let frequencies = &encoded.frequencies;
    let total: i32 = frequencies.iter().sum();
    let data_size = total as usize;

    let mut low_table = [0i32; 256];
    let mut high_table = [0i32; 256];
    let mut cum = 0;
    for i in 0..256 {
        low_table[i] = cum;
        cum += frequencies[i];
        high_table[i] = cum;
    }

    let mut result = vec![0u8; data_size];
    let mut input = BitInputStream::new(&encoded.data);

    let mut value = 0u64;
    for _ in 0..32 {
        value = (value << 1) | input.read_bit() as u64;
    }

    let mut low = 0u64;
    let mut high = 0xFFFFFFFFu64;

    for j in 0..data_size {
        let range = high - low + 1;
        let scaled = ((value - low + 1) * total as u64 - 1) / range;

        let mut symbol: u8 = 0;
        while symbol < 255 && high_table[symbol as usize] as u64 <= scaled {
            symbol += 1;
        }

        result[j] = symbol as u8;

        high = low + (range * high_table[symbol as usize] as u64 / total as u64) - 1;
        low = low + (range * low_table[symbol as usize] as u64 / total as u64);

        loop {
            if high >= 0x80000000 && low < 0x80000000 && (low < 0x40000000 || high >= 0xC0000000) {
                break;
            }

            if high < 0x80000000 {
            } else if low >= 0x80000000 {
                value -= 0x80000000;
                low -= 0x80000000;
                high -= 0x80000000;
            } else if low >= 0x40000000 && high < 0xC0000000 {
                value -= 0x40000000;
                low -= 0x40000000;
                high -= 0x40000000;
            }

            low <<= 1;
            high = (high << 1) | 1;
            value = (value << 1) | input.read_bit() as u64;
        }
    }

    result
}

impl Benchmark for ArithDecode {
    fn name(&self) -> String {
        "Compress::ArithDecode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);

        let mut encoder = ArithEncode::new();
        encoder.size_val = self.size_val;
        encoder.prepare();

        let data = self.test_data.clone();
        encoder.test_data = data;
        encoder.run(0);

        self.encoded = encoder.encoded;
    }

    fn run(&mut self, _iteration_id: i64) {
        self.decoded = arith_decode(&mut self.encoded);
        self.result_val = self.result_val.wrapping_add(self.decoded.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let mut res = self.result_val;
        if self.decoded == self.test_data {
            res = res.wrapping_add(100000);
        }
        res
    }
}

pub struct LZWEncode {
    size_val: i64,
    result_val: u32,
    test_data: Vec<u8>,
    encoded: LZWResult,
}

#[derive(Default)]
pub struct LZWResult {
    data: Vec<u8>,
    dict_size: i32,
}

impl LZWResult {
    fn new() -> Self {
        Self {
            data: Vec::new(),
            dict_size: 256,
        }
    }
}

impl LZWEncode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::LZWEncode", "size");
        Self {
            size_val,
            result_val: 0,
            test_data: Vec::new(),
            encoded: LZWResult::new(),
        }
    }

    fn lzw_encode(&self, input: &[u8]) -> LZWResult {
        if input.is_empty() {
            return LZWResult::new();
        }

        let mut dict = HashMap::with_capacity(4096);
        for i in 0..256 {
            let s = String::from_utf8_lossy(&[i as u8]).to_string();
            dict.insert(s, i);
        }

        let mut next_code = 256;

        let mut result = Vec::with_capacity(input.len() * 2);

        let current_str = String::from_utf8_lossy(&[input[0]]).to_string();
        let mut current = current_str;

        for i in 1..input.len() {
            let next_char_str = String::from_utf8_lossy(&[input[i]]).to_string();
            let new_str = current.clone() + &next_char_str;

            if dict.contains_key(&new_str) {
                current = new_str;
            } else {
                let code = dict[&current];
                result.push(((code >> 8) & 0xFF) as u8);
                result.push((code & 0xFF) as u8);

                dict.insert(new_str, next_code);
                next_code += 1;
                current = next_char_str;
            }
        }

        let code = dict[&current];
        result.push(((code >> 8) & 0xFF) as u8);
        result.push((code & 0xFF) as u8);

        LZWResult {
            data: result,
            dict_size: next_code,
        }
    }
}

impl Benchmark for LZWEncode {
    fn name(&self) -> String {
        "Compress::LZWEncode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);
    }

    fn run(&mut self, _iteration_id: i64) {
        self.encoded = self.lzw_encode(&self.test_data);
        self.result_val = self.result_val.wrapping_add(self.encoded.data.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

pub struct LZWDecode {
    size_val: i64,
    result_val: u32,
    test_data: Vec<u8>,
    decoded: Vec<u8>,
    encoded: LZWResult,
}

impl LZWDecode {
    pub fn new() -> Self {
        let size_val = config_i64("Compress::LZWDecode", "size");
        Self {
            size_val,
            result_val: 0,
            test_data: Vec::new(),
            decoded: Vec::new(),
            encoded: LZWResult::new(),
        }
    }
}

fn lzw_decode(encoded: &LZWResult) -> Vec<u8> {
    if encoded.data.is_empty() {
        return Vec::new();
    }

    let mut dict: Vec<String> = Vec::with_capacity(4096);
    for i in 0..256 {
        dict.push(String::from_utf8_lossy(&[i as u8]).to_string());
    }

    let mut result = Vec::with_capacity(encoded.data.len() * 2);
    let data = &encoded.data;
    let mut pos = 0;

    let high = data[pos] as u16;
    let low = data[pos + 1] as u16;
    let old_code = ((high as usize) << 8) | (low as usize);
    pos += 2;

    let old_str = dict[old_code].clone();
    result.extend_from_slice(old_str.as_bytes());

    let mut next_code = 256;
    let mut old_str = old_str;

    while pos < data.len() {
        let high = data[pos] as u16;
        let low = data[pos + 1] as u16;
        let new_code = ((high as usize) << 8) | (low as usize);
        pos += 2;

        let new_str = if new_code < dict.len() {
            dict[new_code].clone()
        } else if new_code == next_code {
            old_str.clone() + &old_str[0..1]
        } else {
            panic!("Decode error");
        };

        result.extend_from_slice(new_str.as_bytes());

        dict.push(old_str.clone() + &new_str[0..1]);
        next_code += 1;

        old_str = new_str;
    }

    result
}

impl Benchmark for LZWDecode {
    fn name(&self) -> String {
        "Compress::LZWDecode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = generate_test_data(self.size_val);

        let mut encoder = LZWEncode::new();
        encoder.size_val = self.size_val;
        encoder.prepare();
        encoder.run(0);

        self.encoded = encoder.encoded;
    }

    fn run(&mut self, _iteration_id: i64) {
        self.decoded = lzw_decode(&mut self.encoded);
        self.result_val = self.result_val.wrapping_add(self.decoded.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let mut res = self.result_val;
        if self.decoded == self.test_data {
            res = res.wrapping_add(100000);
        }
        res
    }
}
