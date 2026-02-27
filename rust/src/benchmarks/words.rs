use super::super::{helper, Benchmark};
use crate::config_i64;
use std::collections::HashMap;

pub struct Words {
    words: usize,
    word_len: usize,
    text: String,
    checksum_val: u32,
}

impl Words {
    pub fn new() -> Self {
        let words = config_i64("Etc::Words", "words") as usize;
        let word_len = config_i64("Etc::Words", "word_len") as usize;

        Self {
            words,
            word_len,
            text: String::new(),
            checksum_val: 0,
        }
    }
}

impl Benchmark for Words {
    fn name(&self) -> String {
        "Etc::Words".to_string()
    }

    fn prepare(&mut self) {
        let chars: Vec<char> = ('a'..='z').collect();
        let mut text = String::with_capacity(self.words * (self.word_len + 1));

        for i in 0..self.words {
            let word_len =
                helper::next_int(self.word_len as i32) as usize + helper::next_int(3) as usize + 3;

            for _ in 0..word_len {
                text.push(chars[helper::next_int(chars.len() as i32) as usize]);
            }
            if i < self.words - 1 {
                text.push(' ');
            }
        }

        self.text = text;
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut frequencies = HashMap::new();

        for word in self.text.split_whitespace() {
            *frequencies.entry(word.to_string()).or_insert(0) += 1;
        }

        let (max_word, max_count) = frequencies
            .iter()
            .max_by_key(|(_, &count)| count)
            .map(|(word, &count)| (word.clone(), count))
            .unwrap_or((String::new(), 0));

        self.checksum_val = self
            .checksum_val
            .wrapping_add(max_count)
            .wrapping_add(helper::checksum_str(&max_word))
            .wrapping_add(frequencies.len() as u32);
    }

    fn checksum(&self) -> u32 {
        self.checksum_val
    }
}
