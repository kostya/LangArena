use super::super::{helper, Benchmark};
use crate::config_i64;

const LINE_LENGTH: usize = 60;

pub struct Fasta {
    pub(crate) n: i64,
    result_str: String,
}

impl Fasta {
    pub fn new() -> Self {
        let n = config_i64("Fasta", "n");

        Self {
            n,
            result_str: String::new(),
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
        self.result_str.push_str(&format!(">{} {}\n", id, desc));

        let mut todo = n;
        while todo > 0 {
            let m = if todo < LINE_LENGTH {
                todo
            } else {
                LINE_LENGTH
            };

            let mut line = String::with_capacity(m);
            for _ in 0..m {
                line.push(self.select_random(genelist));
            }

            self.result_str.push_str(&format!("{}\n", line));
            todo -= m;
        }
    }

    fn make_repeat_fasta(&mut self, id: &str, desc: &str, s: &str, n: usize) {
        self.result_str.push_str(&format!(">{} {}\n", id, desc));

        let mut todo = n;
        let mut k = 0;
        let kn = s.len();

        while todo > 0 {
            let m = if todo < LINE_LENGTH {
                todo
            } else {
                LINE_LENGTH
            };
            let mut remaining = m;

            while remaining >= kn - k {
                self.result_str.push_str(&s[k..]);
                remaining -= kn - k;
                k = 0;
            }

            if remaining > 0 {
                self.result_str.push_str(&s[k..k + remaining]);
                k += remaining;
            }

            self.result_str.push('\n');
            todo -= m;
        }
    }

    pub fn get_result(&self) -> &str {
        &self.result_str
    }
}

impl Benchmark for Fasta {
    fn name(&self) -> String {
        "Fasta".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        const ALU: &str = "GGCCGGGCGCGGTGGCTCACGCCTGTAATCCCAGCACTTTGGGAGGCCGAGGCGGGCGGATCACCTGAGGTCAGGAGTTCGAGACCAGCCTGGCCAACATGGTGAAACCCCGTCTCTACTAAAAATACAAAAATTAGCCGGGCGTGGTGGCGCGCGCCTGTAATCCCAGCTACTCGGGAGGCTGAGGCAGGAGAATCGCTTGAACCCGGGAGGCGGAGGTTGCAGTGAGCCGAGATCGCGCCACTGCACTCCAGCCTGGGCGACAGAGCGAGACTCCGTCTCAAAAA";

        const IUB: [(char, f64); 15] = [
            ('a', 0.27),
            ('c', 0.39),
            ('g', 0.51),
            ('t', 0.78),
            ('B', 0.8),
            ('D', 0.8200000000000001),
            ('H', 0.8400000000000001),
            ('K', 0.8600000000000001),
            ('M', 0.8800000000000001),
            ('N', 0.9000000000000001),
            ('R', 0.9200000000000002),
            ('S', 0.9400000000000002),
            ('V', 0.9600000000000002),
            ('W', 0.9800000000000002),
            ('Y', 1.0000000000000002),
        ];

        const HOMO: [(char, f64); 4] = [
            ('a', 0.302954942668),
            ('c', 0.5009432431601),
            ('g', 0.6984905497992),
            ('t', 1.0),
        ];

        let n = self.n as usize;
        self.make_repeat_fasta("ONE", "Homo sapiens alu", ALU, n * 2);
        self.make_random_fasta("TWO", "IUB ambiguity codes", &IUB, n * 3);
        self.make_random_fasta("THREE", "Homo sapiens frequency", &HOMO, n * 5);
    }

    fn checksum(&self) -> u32 {
        helper::checksum_str(&self.result_str)
    }
}
