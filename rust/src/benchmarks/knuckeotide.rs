use super::super::{Benchmark, INPUT, helper};
use std::io::Write;
use std::collections::HashMap;
use crate::benchmarks::fasta::Fasta;

pub struct Knuckeotide {
    seq: String,
    result: Vec<u8>,
    n: i32,
}

impl Knuckeotide {
    pub fn new() -> Self {
        let name = "Knuckeotide".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            seq: String::new(),
            result: Vec::new(),
        }
    }

    fn frequency<'a>(&self, seq: &'a str, length: usize) -> (usize, HashMap<String, i32>) {
        let n = seq.len().saturating_sub(length) + 1;
        let mut table = HashMap::new();
        
        for i in 0..n {
            let slice = &seq[i..i + length];
            let key = slice.to_string();
            *table.entry(key).or_insert(0) += 1;
        }
        
        (n, table)
    }

    fn sort_by_freq(&mut self, seq: &str, length: usize) {
        let (n, table) = self.frequency(seq, length);
        let mut entries: Vec<_> = table.into_iter().collect();
        
        entries.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
        
        for (seq_str, count) in entries {
            let freq = (count as f64 * 100.0) / n as f64;
            writeln!(&mut self.result, "{} {:.3}", seq_str.to_uppercase(), freq).unwrap();
        }
        writeln!(&mut self.result).unwrap();
    }

    fn find_seq(&mut self, seq: &str, pattern: &str) {
        let (_n, table) = self.frequency(seq, pattern.len());
        let count = table.get(pattern).copied().unwrap_or(0);
        writeln!(&mut self.result, "{}\t{}", count, pattern.to_uppercase()).unwrap();
    }
}

impl Benchmark for Knuckeotide {
    fn name(&self) -> String {
        "Knuckeotide".to_string()
    }
    
    fn prepare(&mut self) {
        // Создаем Fasta бенчмарк для получения последовательности
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run();
        
        // Используем публичный метод для получения результата как строки
        let result_str = fasta.result_string();
        
        // Извлекаем последовательность THREE из результата Fasta
        let mut three_section = false;
        let mut seq_buf = String::new();
        
        for line in result_str.lines() {
            if line.starts_with(">THREE") {
                three_section = true;
                continue;
            }
            if line.starts_with('>') && three_section {
                break;
            }
            if three_section {
                seq_buf.push_str(line.trim());
            }
        }
        
        self.seq = seq_buf;
    }
    
    fn run(&mut self) {
        let seq_clone = self.seq.clone(); // Клонируем, чтобы избежать одновременного заимствования
        
        // Сортировка по частоте для длин 1 и 2
        for i in 1..=2 {
            self.sort_by_freq(&seq_clone, i);
        }
        
        // Поиск конкретных последовательностей
        let patterns = ["ggt", "ggta", "ggtatt", "ggtattttaatt", "ggtattttaatttatagt"];
        for pattern in patterns {
            self.find_seq(&seq_clone, pattern);
        }
    }
    
    fn result(&self) -> i64 {
        let result_str = String::from_utf8_lossy(&self.result);
        helper::checksum_str(&result_str) as i64
    }
}