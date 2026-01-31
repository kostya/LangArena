use super::super::{Benchmark, helper};
use crate::config_i64;
use crate::benchmarks::fasta::Fasta;

pub struct Revcomp {
    input: String,
    result_val: u32,
    n: i64,
}

impl Revcomp {
    pub fn new() -> Self {
        let n = config_i64("Revcomp", "n");
        
        Self {
            n,
            input: String::new(),
            result_val: 0
        }
    }

    fn revcomp(seq: &str) -> String {
        let mut result = String::new();
        
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
            result.push_str(std::str::from_utf8(chunk).unwrap());
            result.push('\n');
        }

        result
    }
}

impl Benchmark for Revcomp {
    fn name(&self) -> String {
        "Revcomp".to_string()
    }
    
    fn prepare(&mut self) {
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run(0);
        let fasta_result = fasta.get_result();
        
        let mut seq = String::new();
        
        for line in fasta_result.lines() {
            if line.starts_with('>') {
                seq.push_str("\n---\n");
            } else {
                seq.push_str(line.trim());
            }
        }
        
        self.input = seq;
    }
    
    fn run(&mut self, _iteration_id: i64) {
        let rev = Self::revcomp(&self.input);
        // Используем &str, передавая ссылку на String
        self.result_val = self.result_val.wrapping_add(helper::checksum_str(&rev));
    }
    
    fn checksum(&self) -> u32 {
        self.result_val
    }
}

// Для многопоточности
unsafe impl Send for Revcomp {}
unsafe impl Sync for Revcomp {}