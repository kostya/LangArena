use super::super::{helper, Benchmark};
use crate::config_i64;
use std::collections::HashMap;

pub struct Jaro {
    count: usize,
    size: usize,
    pairs: Vec<(String, String)>,
    result_val: u32,
}

impl Jaro {
    pub fn new() -> Self {
        let count = config_i64("Distance::Jaro", "count") as usize;
        let size = config_i64("Distance::Jaro", "size") as usize;

        Self {
            count,
            size,
            pairs: Vec::new(),
            result_val: 0,
        }
    }

    fn generate_pair_strings(&self, n: usize, m: usize) -> Vec<(String, String)> {
        let mut pairs = Vec::with_capacity(n);
        let chars: Vec<char> = "abcdefghij".chars().collect();

        for _ in 0..n {
            let len1 = helper::next_int(m as i32) as usize + 4;
            let len2 = helper::next_int(m as i32) as usize + 4;

            let str1: String = (0..len1)
                .map(|_| chars[helper::next_int(10) as usize])
                .collect();
            let str2: String = (0..len2)
                .map(|_| chars[helper::next_int(10) as usize])
                .collect();

            pairs.push((str1, str2));
        }

        pairs
    }

    fn jaro(s1: &str, s2: &str) -> f64 {
        let bytes1 = s1.as_bytes();
        let bytes2 = s2.as_bytes();

        let len1 = bytes1.len();
        let len2 = bytes2.len();

        if len1 == 0 || len2 == 0 {
            return 0.0;
        }

        let match_dist = len1.max(len2) / 2 - 1;
        let match_dist = if match_dist < 0 {
            0
        } else {
            match_dist as usize
        };

        let mut s1_matches = vec![false; len1];
        let mut s2_matches = vec![false; len2];

        let mut matches = 0;
        for i in 0..len1 {
            let start = i.saturating_sub(match_dist);
            let end = (len2 - 1).min(i + match_dist);

            for j in start..=end {
                if !s2_matches[j] && bytes1[i] == bytes2[j] {
                    s1_matches[i] = true;
                    s2_matches[j] = true;
                    matches += 1;
                    break;
                }
            }
        }

        if matches == 0 {
            return 0.0;
        }

        let mut transpositions = 0;
        let mut k = 0;
        for i in 0..len1 {
            if s1_matches[i] {
                while k < len2 && !s2_matches[k] {
                    k += 1;
                }
                if k < len2 {
                    if bytes1[i] != bytes2[k] {
                        transpositions += 1;
                    }
                    k += 1;
                }
            }
        }
        transpositions /= 2;

        let m = matches as f64;
        (m / len1 as f64 + m / len2 as f64 + (m - transpositions as f64) / m) / 3.0
    }
}

impl Benchmark for Jaro {
    fn name(&self) -> String {
        "Distance::Jaro".to_string()
    }

    fn prepare(&mut self) {
        self.pairs = self.generate_pair_strings(self.count, self.size);
        self.result_val = 0;
    }

    fn run(&mut self, _iteration_id: i64) {
        for (s1, s2) in &self.pairs {
            self.result_val = self
                .result_val
                .wrapping_add((Self::jaro(s1, s2) * 1000.0) as u32);
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

pub struct NGram {
    count: usize,
    size: usize,
    pairs: Vec<(String, String)>,
    result_val: u32,
    n: usize,
}

impl NGram {
    pub fn new() -> Self {
        let count = config_i64("Distance::NGram", "count") as usize;
        let size = config_i64("Distance::NGram", "size") as usize;

        Self {
            count,
            size,
            pairs: Vec::new(),
            result_val: 0,
            n: 4,
        }
    }

    fn generate_pair_strings(&self, n: usize, m: usize) -> Vec<(String, String)> {
        let mut pairs = Vec::with_capacity(n);
        let chars: Vec<char> = "abcdefghij".chars().collect();

        for _ in 0..n {
            let len1 = helper::next_int(m as i32) as usize + 4;
            let len2 = helper::next_int(m as i32) as usize + 4;

            let str1: String = (0..len1)
                .map(|_| chars[helper::next_int(10) as usize])
                .collect();
            let str2: String = (0..len2)
                .map(|_| chars[helper::next_int(10) as usize])
                .collect();

            pairs.push((str1, str2));
        }

        pairs
    }

    fn ngram(&self, s1: &str, s2: &str) -> f64 {
        let s1_bytes = s1.as_bytes();
        let s2_bytes = s2.as_bytes();

        let len1 = s1_bytes.len();
        let len2 = s2_bytes.len();

        if len1 < self.n || len2 < self.n {
            return 0.0;
        }

        let mut grams1 = HashMap::with_capacity(len1);

        for i in 0..=len1 - self.n {
            let gram = ((s1_bytes[i] as u32) << 24)
                | ((s1_bytes[i + 1] as u32) << 16)
                | ((s1_bytes[i + 2] as u32) << 8)
                | (s1_bytes[i + 3] as u32);

            *grams1.entry(gram).and_modify(|e| *e += 1).or_insert(1);
        }

        let mut grams2 = HashMap::with_capacity(len2);
        let mut intersection = 0;

        for i in 0..=len2 - self.n {
            let gram = ((s2_bytes[i] as u32) << 24)
                | ((s2_bytes[i + 1] as u32) << 16)
                | ((s2_bytes[i + 2] as u32) << 8)
                | (s2_bytes[i + 3] as u32);

            *grams2.entry(gram).and_modify(|e| *e += 1).or_insert(1);

            if let Some(&count1) = grams1.get(&gram) {
                if grams2[&gram] <= count1 {
                    intersection += 1;
                }
            }
        }

        let total = grams1.len() + grams2.len();
        if total > 0 {
            intersection as f64 / total as f64
        } else {
            0.0
        }
    }
}

impl Benchmark for NGram {
    fn name(&self) -> String {
        "Distance::NGram".to_string()
    }

    fn prepare(&mut self) {
        self.pairs = self.generate_pair_strings(self.count, self.size);
        self.result_val = 0;
    }

    fn run(&mut self, _iteration_id: i64) {
        for (s1, s2) in &self.pairs {
            self.result_val = self
                .result_val
                .wrapping_add((self.ngram(s1, s2) * 1000.0) as u32);
        }
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
