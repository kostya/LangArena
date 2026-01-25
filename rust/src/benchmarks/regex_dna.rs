use super::super::{Benchmark, INPUT, helper};
use std::io::Write;
use regex::Regex;
use crate::benchmarks::fasta::Fasta;

pub struct RegexDna {
    seq: String,
    ilen: usize,
    clen: usize,
    result: Vec<u8>,
    n: i32,
}

impl RegexDna {
    pub fn new() -> Self {
        let name = "RegexDna".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            seq: String::new(),
            ilen: 0,
            clen: 0,
            result: Vec::new(),
        }
    }
}

impl Benchmark for RegexDna {
    fn name(&self) -> String {
        "RegexDna".to_string()
    }
    
    fn prepare(&mut self) {
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run();
        let res = fasta.result_string();
        
        let mut seq_buf = String::new();
        self.ilen = 0;
        
        for line in res.lines() {
            self.ilen += line.len() + 1;
            if !line.starts_with('>') {
                seq_buf.push_str(line.trim());
            }
        }
        
        self.seq = seq_buf;
        self.clen = self.seq.len();
    }
    
    fn run(&mut self) {
        let patterns = [
            (r"agggtaaa|tttaccct", "agggtaaa|tttaccct"),
            (r"[cgt]gggtaaa|tttaccc[acg]", "[cgt]gggtaaa|tttaccc[acg]"),
            (r"a[act]ggtaaa|tttacc[agt]t", "a[act]ggtaaa|tttacc[agt]t"),
            (r"ag[act]gtaaa|tttac[agt]ct", "ag[act]gtaaa|tttac[agt]ct"),
            (r"agg[act]taaa|ttta[agt]cct", "agg[act]taaa|ttta[agt]cct"),
            (r"aggg[acg]aaa|ttt[cgt]ccct", "aggg[acg]aaa|ttt[cgt]ccct"),
            (r"agggt[cgt]aa|tt[acg]accct", "agggt[cgt]aa|tt[acg]accct"),
            (r"agggta[cgt]a|t[acg]taccct", "agggta[cgt]a|t[acg]taccct"),
            (r"agggtaa[cgt]|[acg]ttaccct", "agggtaa[cgt]|[acg]ttaccct"),
        ];
        
        for (pattern, display) in &patterns {
            let re = Regex::new(pattern).unwrap();
            let count = re.find_iter(&self.seq).count();
            writeln!(&mut self.result, "{} {}", display, count).unwrap();
        }
        
        let replacements = [
            ("B", "(c|g|t)"),
            ("D", "(a|g|t)"),
            ("H", "(a|c|t)"),
            ("K", "(g|t)"),
            ("M", "(a|c)"),
            ("N", "(a|c|g|t)"),
            ("R", "(a|g)"),
            ("S", "(c|t)"),
            ("V", "(a|c|g)"),
            ("W", "(a|t)"),
            ("Y", "(c|t)"),
        ];
        
        let mut seq = self.seq.clone();
        for (from, to) in &replacements {
            let re = Regex::new(from).unwrap();
            seq = re.replace_all(&seq, *to).to_string();
        }
        
        writeln!(&mut self.result).unwrap();
        writeln!(&mut self.result, "{}", self.ilen).unwrap();
        writeln!(&mut self.result, "{}", self.clen).unwrap();
        writeln!(&mut self.result, "{}", seq.len()).unwrap();
    }
    
    fn result(&self) -> i64 {
        let result_str = String::from_utf8_lossy(&self.result);
        helper::checksum_str(&result_str) as i64
    }
}