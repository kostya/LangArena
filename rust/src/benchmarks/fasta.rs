use super::super::{Benchmark, INPUT, helper};
use std::io::Write;

const LINE_LENGTH: usize = 60;

pub struct Fasta {
    pub(crate) n: i32,
    pub(crate) result: Vec<u8>,
}

impl Fasta {
    pub fn new() -> Self {
        let name = "Fasta".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: Vec::new(),
        }
    }

    fn select_random(&self, genelist: &[(char, f64)]) -> char {
        let r = helper::next_float(1.0);
        
        if r < genelist[0].1 {
            return genelist[0].0;
        }
        
        let mut lo = 0;
        let mut hi = genelist.len() - 1;
        
        while hi > lo + 1 {
            let i = (hi + lo) / 2;
            if r < genelist[i].1 {
                hi = i;
            } else {
                lo = i;
            }
        }
        genelist[hi].0
    }

    fn make_random_fasta(&mut self, id: &str, desc: &str, genelist: &[(char, f64)], n: usize) {
        writeln!(&mut self.result, ">{} {}", id, desc).unwrap();
        
        let mut todo = n;
        while todo > 0 {
            let m = if todo < LINE_LENGTH { todo } else { LINE_LENGTH };
            
            let mut line = String::with_capacity(m);
            for _ in 0..m {
                line.push(self.select_random(genelist));
            }
            
            writeln!(&mut self.result, "{}", line).unwrap();
            todo -= m;
        }
    }

    fn make_repeat_fasta(&mut self, id: &str, desc: &str, s: &str, n: usize) {
        writeln!(&mut self.result, ">{} {}", id, desc).unwrap();
        
        let mut todo = n;
        let mut k = 0;
        let kn = s.len();
        
        while todo > 0 {
            let m = if todo < LINE_LENGTH { todo } else { LINE_LENGTH };
            let mut remaining = m;
            
            while remaining >= kn - k {
                let chunk = &s[k..];
                write!(&mut self.result, "{}", chunk).unwrap();
                remaining -= kn - k;
                k = 0;
            }
            
            if remaining > 0 {
                let chunk = &s[k..k + remaining];
                write!(&mut self.result, "{}", chunk).unwrap();
                k += remaining;
            }
            
            writeln!(&mut self.result).unwrap();
            todo -= m;
        }
    }    
    // Публичный метод для получения результата как строки
    pub fn result_string(&self) -> String {
        String::from_utf8_lossy(&self.result).to_string()
    }
}

impl Benchmark for Fasta {
    fn name(&self) -> String {
        "Fasta".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        const ALU: &str = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";
        
        const IUB: [(char, f64); 15] = [
            ('a', 0.27), ('c', 0.39), ('g', 0.51), ('t', 0.78), ('B', 0.8), 
            ('D', 0.8200000000000001), ('H', 0.8400000000000001), ('K', 0.8600000000000001), 
            ('M', 0.8800000000000001), ('N', 0.9000000000000001), ('R', 0.9200000000000002), 
            ('S', 0.9400000000000002), ('V', 0.9600000000000002), ('W', 0.9800000000000002), 
            ('Y', 1.0000000000000002)
        ];
        
        const HOMO: [(char, f64); 4] = [
            ('a', 0.302954942668), ('c', 0.5009432431601), 
            ('g', 0.6984905497992), ('t', 1.0)
        ];
        
        let n = self.n as usize;
        self.make_repeat_fasta("ONE", "Homo sapiens alu", ALU, n * 2);
        self.make_random_fasta("TWO", "IUB ambiguity codes", &IUB, n * 3);
        self.make_random_fasta("THREE", "Homo sapiens frequency", &HOMO, n * 5);
    }
    
    fn result(&self) -> i64 {
        let result_str = String::from_utf8_lossy(&self.result);
        helper::checksum_str(&result_str) as i64
    }
}