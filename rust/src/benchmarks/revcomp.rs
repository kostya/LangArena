use super::super::{Benchmark, INPUT, helper};
use std::io::Write;
use crate::benchmarks::fasta::Fasta;

pub struct Revcomp {
    input_lines: Vec<String>,
    result: Vec<u8>,
    n: i32,
}

impl Revcomp {
    pub fn new() -> Self {
        let name = "Revcomp".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            input_lines: Vec::new(),
            result: Vec::new(),
        }
    }

    fn revcomp(result: &mut Vec<u8>, seq: &str) {
        // Таблица трансляции как в Crystal: 
        // from: "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        // to:   "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
        
        let trans_table = |c: char| -> char {
            match c {
                'w' => 'W', 's' => 'S', 'a' => 'T', 't' => 'A', 'u' => 'A', 'g' => 'C',
                'c' => 'G', 'y' => 'R', 'r' => 'Y', 'k' => 'M', 'm' => 'K', 'b' => 'V',
                'd' => 'H', 'h' => 'D', 'v' => 'B', 'n' => 'N',
                'A' => 'T', 'T' => 'A', 'U' => 'A', 'G' => 'C', 'C' => 'G', 'Y' => 'R',
                'R' => 'Y', 'K' => 'M', 'M' => 'K', 'B' => 'V', 'D' => 'H', 'H' => 'D',
                'V' => 'B', 'N' => 'N',
                _ => c,  // оставляем неизменным если не в таблице
            }
        };
        
        // Собираем обратную комплементарную последовательность
        let transformed: String = seq.chars().rev().map(trans_table).collect();
        
        // Разбиваем на строки по 60 символов
        for chunk in transformed.as_bytes().chunks(60) {
            result.extend_from_slice(chunk);
            result.push(b'\n');
        }
    }
}

impl Benchmark for Revcomp {
    fn name(&self) -> String {
        "Revcomp".to_string()
    }
    
    fn prepare(&mut self) {
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run();
        let input_str = fasta.result_string();
        
        // Сохраняем строки в вектор
        self.input_lines = input_str.lines().map(String::from).collect();
    }
    
    fn run(&mut self) {
        let mut seq_buf = String::new();
        
        // Используем итератор, чтобы избежать заимствования self
        let mut lines_iter = self.input_lines.iter();
        
        while let Some(line) = lines_iter.next() {
            if line.starts_with('>') {
                if !seq_buf.is_empty() {
                    Self::revcomp(&mut self.result, &seq_buf);
                    seq_buf.clear();
                }
                writeln!(&mut self.result, "{}", line).unwrap();
            } else {
                seq_buf.push_str(line.trim());
            }
        }
        
        if !seq_buf.is_empty() {
            Self::revcomp(&mut self.result, &seq_buf);
        }
    }
    
    fn result(&self) -> i64 {
        let result_str = String::from_utf8_lossy(&self.result);
        helper::checksum_str(&result_str) as i64
    }
}