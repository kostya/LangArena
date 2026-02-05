use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;
use super::super::{Benchmark, helper};
use crate::config_i64;

#[derive(Debug, Clone)]
struct BWTResult {
    transformed: Vec<u8>,
    original_idx: usize,
}

fn bwt_transform(input: &[u8]) -> BWTResult {
    let n = input.len();
    if n == 0 {
        return BWTResult {
            transformed: Vec::new(),
            original_idx: 0,
        };
    }

    let mut sa: Vec<usize> = (0..n).collect();

    let mut buckets: Vec<Vec<usize>> = vec![Vec::new(); 256];

    for &idx in &sa {
        let first_char = input[idx];
        buckets[first_char as usize].push(idx);
    }

    let mut pos = 0;
    for bucket in &buckets {
        for &idx in bucket {
            sa[pos] = idx;
            pos += 1;
        }
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

            let mut pairs = vec![(0, 0); n];
            for i in 0..n {
                pairs[i] = (rank[i], rank[(i + k) % n]);
            }

            sa.sort_by(|&a, &b| {
                let pa = pairs[a];
                let pb = pairs[b];
                if pa.0 != pb.0 {
                    pa.0.cmp(&pb.0)
                } else {
                    pa.1.cmp(&pb.1)
                }
            });

            let mut new_rank = vec![0; n];
            new_rank[sa[0]] = 0;
            for i in 1..n {
                let prev_pair = pairs[sa[i - 1]];
                let curr_pair = pairs[sa[i]];
                new_rank[sa[i]] = new_rank[sa[i - 1]]
                    + if prev_pair != curr_pair { 1 } else { 0 };
            }

            rank = new_rank;
            k *= 2;
        }
    }

    let mut transformed = Vec::with_capacity(n);
    let mut original_idx = 0;

    for (i, &suffix) in sa.iter().enumerate() {
        if suffix == 0 {
            transformed.push(input[n - 1]);
            original_idx = i;
        } else {
            transformed.push(input[suffix - 1]);
        }
    }

    BWTResult {
        transformed,
        original_idx,
    }
}

fn bwt_inverse(bwt_result: &BWTResult) -> Vec<u8> {
    let bwt = &bwt_result.transformed;
    let original_idx = bwt_result.original_idx;
    let n = bwt.len();

    if n == 0 {
        return Vec::new();
    }

    let mut counts = [0usize; 256];
    for &byte in bwt {
        counts[byte as usize] += 1;
    }

    let mut positions = [0usize; 256];
    let mut total = 0;
    for i in 0..256 {
        positions[i] = total;
        total += counts[i];
    }

    let mut next = vec![0usize; n];
    let mut temp_counts = [0usize; 256];

    for (i, &byte) in bwt.iter().enumerate() {
        let byte_idx = byte as usize;
        let pos = positions[byte_idx] + temp_counts[byte_idx];
        next[pos] = i;
        temp_counts[byte_idx] += 1;
    }

    let mut result = Vec::with_capacity(n);
    let mut idx = original_idx;

    for _ in 0..n {
        idx = next[idx];
        result.push(bwt[idx]);
    }

    result
}

#[derive(Debug, Eq, PartialEq)]
struct HuffmanNode {
    frequency: u32,
    byte: Option<u8>,
    left: Option<Box<HuffmanNode>>,
    right: Option<Box<HuffmanNode>>,
}

impl Ord for HuffmanNode {
    fn cmp(&self, other: &Self) -> Ordering {

        other.frequency.cmp(&self.frequency)
    }
}

impl PartialOrd for HuffmanNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

fn build_huffman_tree(frequencies: &[u32; 256]) -> Option<Box<HuffmanNode>> {
    let mut heap = BinaryHeap::new();

    for (byte, &freq) in frequencies.iter().enumerate() {
        if freq > 0 {
            heap.push(Box::new(HuffmanNode {
                frequency: freq,
                byte: Some(byte as u8),
                left: None,
                right: None,
            }));
        }
    }

    if heap.len() == 1 {
        let node = heap.pop().unwrap();
        return Some(Box::new(HuffmanNode {
            frequency: node.frequency,
            byte: None,
            left: Some(node),
            right: Some(Box::new(HuffmanNode {
                frequency: 0,
                byte: Some(0), 
                left: None,
                right: None,
            })),
        }));
    }

    while heap.len() > 1 {
        let left = heap.pop().unwrap();
        let right = heap.pop().unwrap();

        let parent = Box::new(HuffmanNode {
            frequency: left.frequency + right.frequency,
            byte: None,
            left: Some(left),
            right: Some(right),
        });

        heap.push(parent);
    }

    heap.pop()
}

fn build_huffman_codes(node: &HuffmanNode, prefix: Vec<bool>, codes: &mut HashMap<u8, Vec<bool>>) {
    if let Some(byte) = node.byte {
        if !prefix.is_empty() || byte != 0 { 
            codes.insert(byte, prefix);
        }
    } else {
        if let Some(ref left) = node.left {
            let mut left_prefix = prefix.clone();
            left_prefix.push(false);
            build_huffman_codes(left, left_prefix, codes);
        }

        if let Some(ref right) = node.right {
            let mut right_prefix = prefix;
            right_prefix.push(true);
            build_huffman_codes(right, right_prefix, codes);
        }
    }
}

fn huffman_encode(data: &[u8], codes: &HashMap<u8, Vec<bool>>) -> (Vec<u8>, usize) {

    let mut bits = Vec::new();
    for &byte in data {
        if let Some(code) = codes.get(&byte) {
            bits.extend(code);
        } else {

            panic!("Symbol {:?} not found in Huffman codes", byte);
        }
    }

    let mut result = Vec::with_capacity((bits.len() + 7) / 8);
    for chunk in bits.chunks(8) {
        let mut byte = 0u8;
        for (i, &bit) in chunk.iter().enumerate() {
            if bit {
                byte |= 1 << (7 - i);
            }
        }
        result.push(byte);
    }

    (result, bits.len())
}

fn huffman_decode(encoded: &[u8], root: &HuffmanNode, bit_count: usize) -> Vec<u8> {
    let mut result = Vec::new();
    let mut current_node = root;
    let mut bits_processed = 0;

    'outer: for &byte in encoded {
        for bit_pos in 0..8 {
            if bits_processed >= bit_count {
                break 'outer;
            }

            let bit = (byte >> (7 - bit_pos)) & 1 == 1;
            bits_processed += 1;

            current_node = if bit {
                current_node.right.as_ref().unwrap()
            } else {
                current_node.left.as_ref().unwrap()
            };

            if let Some(byte_val) = current_node.byte {
                if byte_val != 0 { 
                    result.push(byte_val);
                }
                current_node = root; 
            }
        }
    }

    result
}

#[derive(Debug, Clone)]
struct CompressedData {
    bwt_result: BWTResult,
    frequencies: [u32; 256],
    encoded_bits: Vec<u8>,
    original_bit_count: usize,
}

fn compress(data: &[u8]) -> CompressedData {

    let bwt_result = bwt_transform(data);

    let mut frequencies = [0u32; 256];
    for &byte in &bwt_result.transformed {
        frequencies[byte as usize] += 1;
    }

    let huffman_tree = build_huffman_tree(&frequencies).unwrap();

    let mut huffman_codes = HashMap::new();
    build_huffman_codes(&huffman_tree, Vec::new(), &mut huffman_codes);

    let (encoded_bits, bit_count) = huffman_encode(&bwt_result.transformed, &huffman_codes);

    CompressedData {
        bwt_result,
        frequencies,
        encoded_bits,
        original_bit_count: bit_count,
    }
}

fn decompress(compressed: &CompressedData) -> Vec<u8> {

    let huffman_tree = build_huffman_tree(&compressed.frequencies).unwrap();

    let decoded = huffman_decode(
        &compressed.encoded_bits,
        &huffman_tree,
        compressed.original_bit_count
    );

    let bwt_result = BWTResult {
        transformed: decoded,
        original_idx: compressed.bwt_result.original_idx,
    };

    bwt_inverse(&bwt_result)
}

pub struct BWTHuffEncode {
    size_val: i64,
    test_data: Vec<u8>,
    result_val: u32,
}

impl BWTHuffEncode {
    pub fn new() -> Self {
        let size_val = config_i64("BWTHuffEncode", "size");

        Self {
            size_val,
            test_data: Vec::new(),
            result_val: 0,
        }
    }

    fn generate_test_data(&self, size: i64) -> Vec<u8> {

        let pattern = b"ABRACADABRA";
        let mut data = Vec::with_capacity(size as usize);

        for i in 0..size {
            data.push(pattern[(i as usize) % pattern.len()]);
        }

        data
    }
}

impl Benchmark for BWTHuffEncode {
    fn name(&self) -> String {
        "BWTHuffEncode".to_string()
    }

    fn prepare(&mut self) {
        self.test_data = self.generate_test_data(self.size_val);
    }

    fn run(&mut self, _iteration_id: i64) {
        let compressed = compress(&self.test_data);
        self.result_val = self.result_val.wrapping_add(compressed.encoded_bits.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

pub struct BWTHuffDecode {
    compression_base: BWTHuffEncode,
    compressed_data: Option<CompressedData>,
    decompressed: Vec<u8>,
}

impl BWTHuffDecode {
    pub fn new() -> Self {
        let size_val = config_i64("BWTHuffDecode", "size");  

        let mut compression_base = BWTHuffEncode {
            size_val,
            test_data: Vec::new(),
            result_val: 0,
        };

        compression_base.test_data = compression_base.generate_test_data(size_val);

        Self {
            compression_base,
            compressed_data: None,
            decompressed: Vec::new(),
        }
    }
}

impl Benchmark for BWTHuffDecode {
    fn name(&self) -> String {
        "BWTHuffDecode".to_string()
    }

    fn prepare(&mut self) {

        let test_data = &self.compression_base.test_data;
        self.compressed_data = Some(compress(test_data));

        self.compression_base.result_val = 0;
    }

    fn run(&mut self, _iteration_id: i64) {

        if let Some(ref compressed) = self.compressed_data {
            self.decompressed = decompress(compressed);

            self.compression_base.result_val = self.compression_base.result_val
                .wrapping_add(self.decompressed.len() as u32);
        }
    }

    fn checksum(&self) -> u32 {
        let mut res = self.compression_base.result_val;

        if self.compressed_data.is_some() && 
           self.decompressed == self.compression_base.test_data {
            res = res.wrapping_add(1000000);
        }

        res
    }
}

unsafe impl Send for BWTHuffEncode {}
unsafe impl Sync for BWTHuffEncode {}
unsafe impl Send for BWTHuffDecode {}
unsafe impl Sync for BWTHuffDecode {}