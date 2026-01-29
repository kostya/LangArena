use std::collections::{BinaryHeap, HashMap};
use std::cmp::Ordering;
use super::super::{Benchmark, helper};
use crate::config_i64;

// ==================== BWT ====================
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

    // 1. Создаём суффиксный массив
    let mut sa: Vec<usize> = (0..n).collect();

    // 2. Фаза 0: сортировка по первому символу (Radix sort)
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

    // 3. Фаза 1: сортировка по парам символов
    if n > 1 {
        // Присваиваем ранги по первому символу
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

        // Сортируем по парам (ранг[i], ранг[i+1])
        let mut k = 1;
        while k < n {
            // Создаём пары
            let mut pairs = vec![(0, 0); n];
            for i in 0..n {
                pairs[i] = (rank[i], rank[(i + k) % n]);
            }

            // Сортируем индексы по парам
            sa.sort_by(|&a, &b| {
                let pa = pairs[a];
                let pb = pairs[b];
                if pa.0 != pb.0 {
                    pa.0.cmp(&pb.0)
                } else {
                    pa.1.cmp(&pb.1)
                }
            });

            // Обновляем ранги
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

    // 4. Собираем BWT результат
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
    
    // 1. Подсчитываем частоты символов
    let mut counts = [0usize; 256];
    for &byte in bwt {
        counts[byte as usize] += 1;
    }
    
    // 2. Вычисляем стартовые позиции для каждого символа
    let mut positions = [0usize; 256];
    let mut total = 0;
    for i in 0..256 {
        positions[i] = total;
        total += counts[i];
    }
    
    // 3. Строим массив next (LF-маппинг)
    let mut next = vec![0usize; n];
    let mut temp_counts = [0usize; 256];
    
    for (i, &byte) in bwt.iter().enumerate() {
        let byte_idx = byte as usize;
        let pos = positions[byte_idx] + temp_counts[byte_idx];
        next[pos] = i;
        temp_counts[byte_idx] += 1;
    }
    
    // 4. Восстанавливаем исходную строку
    let mut result = Vec::with_capacity(n);
    let mut idx = original_idx;
    
    for _ in 0..n {
        idx = next[idx];
        result.push(bwt[idx]);
    }
    
    result
}

// ==================== Huffman ====================
#[derive(Debug, Eq, PartialEq)]
struct HuffmanNode {
    frequency: u32,
    byte: Option<u8>,
    left: Option<Box<HuffmanNode>>,
    right: Option<Box<HuffmanNode>>,
}

impl Ord for HuffmanNode {
    fn cmp(&self, other: &Self) -> Ordering {
        // Для min-heap: меньшая частота = выше приоритет
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
    
    // Добавляем все символы с ненулевой частотой
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
    
    // Если только один символ, создаём искусственный узел
    if heap.len() == 1 {
        let node = heap.pop().unwrap();
        return Some(Box::new(HuffmanNode {
            frequency: node.frequency,
            byte: None,
            left: Some(node),
            right: Some(Box::new(HuffmanNode {
                frequency: 0,
                byte: Some(0), // фиктивный символ
                left: None,
                right: None,
            })),
        }));
    }
    
    // Строим дерево
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
        if !prefix.is_empty() || byte != 0 { // Игнорируем фиктивный символ
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
    // Сначала собираем все биты
    let mut bits = Vec::new();
    for &byte in data {
        if let Some(code) = codes.get(&byte) {
            bits.extend(code);
        } else {
            // Если символ не найден (не должен случаться)
            panic!("Symbol {:?} not found in Huffman codes", byte);
        }
    }
    
    // Упаковываем биты в байты
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
            
            // Читаем бит (старший бит first)
            let bit = (byte >> (7 - bit_pos)) & 1 == 1;
            bits_processed += 1;
            
            // Идём по дереву
            current_node = if bit {
                current_node.right.as_ref().unwrap()
            } else {
                current_node.left.as_ref().unwrap()
            };
            
            // Если достигли листа
            if let Some(byte_val) = current_node.byte {
                if byte_val != 0 { // Игнорируем фиктивный символ
                    result.push(byte_val);
                }
                current_node = root; // Возвращаемся к корню
            }
        }
    }
    
    result
}

// ==================== Компрессор ====================
#[derive(Debug, Clone)]
struct CompressedData {
    bwt_result: BWTResult,
    frequencies: [u32; 256],
    encoded_bits: Vec<u8>,
    original_bit_count: usize,
}

fn compress(data: &[u8]) -> CompressedData {
    // 1. BWT преобразование
    let bwt_result = bwt_transform(data);
    
    // 2. Подсчёт частот для Huffman
    let mut frequencies = [0u32; 256];
    for &byte in &bwt_result.transformed {
        frequencies[byte as usize] += 1;
    }
    
    // 3. Построение дерева Huffman
    let huffman_tree = build_huffman_tree(&frequencies).unwrap();
    
    // 4. Построение кодов
    let mut huffman_codes = HashMap::new();
    build_huffman_codes(&huffman_tree, Vec::new(), &mut huffman_codes);
    
    // 5. Кодирование
    let (encoded_bits, bit_count) = huffman_encode(&bwt_result.transformed, &huffman_codes);
    
    CompressedData {
        bwt_result,
        frequencies,
        encoded_bits,
        original_bit_count: bit_count,
    }
}

fn decompress(compressed: &CompressedData) -> Vec<u8> {
    // 1. Восстанавливаем дерево Huffman из сохранённых частот
    let huffman_tree = build_huffman_tree(&compressed.frequencies).unwrap();
    
    // 2. Декодирование Huffman
    let decoded = huffman_decode(
        &compressed.encoded_bits,
        &huffman_tree,
        compressed.original_bit_count
    );
    
    // 3. Обратное BWT
    let bwt_result = BWTResult {
        transformed: decoded,
        original_idx: compressed.bwt_result.original_idx,
    };
    
    bwt_inverse(&bwt_result)
}

// ==================== Бенчмарк Compression ====================
pub struct Compression {
    size_val: i64,
    test_data: Vec<u8>,
    result_val: u32,
}

impl Compression {
    pub fn new() -> Self {
        let size_val = config_i64("Compression", "size");
        
        Self {
            size_val,
            test_data: Vec::new(),
            result_val: 0,
        }
    }
    
    fn generate_test_data(&self, size: i64) -> Vec<u8> {
        // Простой паттерн для хорошего сжатия
        let pattern = b"ABRACADABRA";
        let mut data = Vec::with_capacity(size as usize);
        
        for i in 0..size {
            data.push(pattern[(i as usize) % pattern.len()]);
        }
        
        data
    }
}

impl Benchmark for Compression {
    fn name(&self) -> String {
        "Compression".to_string()
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

// ==================== Бенчмарк Decompression ====================
pub struct Decompression {
    compression_base: Compression,
    compressed_data: Option<CompressedData>,
    decompressed: Vec<u8>,
}

impl Decompression {
    pub fn new() -> Self {
        // Создаем Compression с правильным size_val
        let size_val = config_i64("Decompression", "size");  // Используем "Decompression", "size"
        
        let mut compression_base = Compression {
            size_val,
            test_data: Vec::new(),
            result_val: 0,
        };
        
        // Генерируем тестовые данные
        compression_base.test_data = compression_base.generate_test_data(size_val);
        
        Self {
            compression_base,
            compressed_data: None,
            decompressed: Vec::new(),
        }
    }
}

impl Benchmark for Decompression {
    fn name(&self) -> String {
        "Decompression".to_string()
    }
    
    fn prepare(&mut self) {
        // НЕ вызываем compression_base.prepare() - мы уже создали test_data в конструкторе
        // Сжимаем тестовые данные
        let test_data = &self.compression_base.test_data;
        self.compressed_data = Some(compress(test_data));
        
        // Сбрасываем result_val на всякий случай
        self.compression_base.result_val = 0;
    }
    
    fn run(&mut self, _iteration_id: i64) {
        // Распаковываем данные
        if let Some(ref compressed) = self.compressed_data {
            self.decompressed = decompress(compressed);
            // Добавляем размер распакованных данных к результату
            self.compression_base.result_val = self.compression_base.result_val
                .wrapping_add(self.decompressed.len() as u32);
        }
    }
    
    fn checksum(&self) -> u32 {
        let mut res = self.compression_base.result_val;
        
        // Проверяем, что распакованные данные совпадают с исходными
        if self.compressed_data.is_some() && 
           self.decompressed == self.compression_base.test_data {
            res = res.wrapping_add(1000000);
        }
        
        res
    }
}

unsafe impl Send for Compression {}
unsafe impl Sync for Compression {}
unsafe impl Send for Decompression {}
unsafe impl Sync for Decompression {}