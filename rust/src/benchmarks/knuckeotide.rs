use super::super::{helper, Benchmark};
use crate::benchmarks::fasta::Fasta;
use crate::config_i64;
use std::collections::HashMap;

pub struct Knuckeotide {
    seq: String,
    result_str: String,
    n: i64,
}

impl Knuckeotide {
    pub fn new() -> Self {
        let n = config_i64("CLBG::Knuckeotide", "n");

        Self {
            n,
            seq: String::new(),
            result_str: String::new(),
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
            self.result_str
                .push_str(&format!("{} {:.3}\n", seq_str.to_uppercase(), freq));
        }
        self.result_str.push('\n');
    }

    fn find_seq(&mut self, seq: &str, pattern: &str) {
        let (_n, table) = self.frequency(seq, pattern.len());
        let count = table.get(&pattern.to_lowercase()).copied().unwrap_or(0);
        self.result_str
            .push_str(&format!("{}\t{}\n", count, pattern.to_uppercase()));
    }
}

impl Benchmark for Knuckeotide {
    fn name(&self) -> String {
        "CLBG::Knuckeotide".to_string()
    }

    fn prepare(&mut self) {
        let mut fasta = Fasta::new();
        fasta.n = self.n;
        fasta.run(0);

        let result_str = fasta.get_result();

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

    fn run(&mut self, _iteration_id: i64) {
        let seq_clone = self.seq.clone();

        for i in 1..=2 {
            self.sort_by_freq(&seq_clone, i);
        }

        let patterns = [
            "ggt",
            "ggta",
            "ggtatt",
            "ggtattttaatt",
            "ggtattttaatttatagt",
        ];
        for pattern in patterns {
            self.find_seq(&seq_clone, pattern);
        }
    }

    fn checksum(&self) -> u32 {
        helper::checksum_str(&self.result_str)
    }
}
