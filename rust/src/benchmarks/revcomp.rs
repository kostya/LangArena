use super::super::{helper, Benchmark};
use crate::benchmarks::fasta::Fasta;
use crate::config_i64;
use std::cell::RefCell;

pub struct Revcomp {
    input: String,
    result_val: u32,
    n: i64,
}

thread_local! {
    static LOOKUP_TABLE: RefCell<[u8; 256]> = RefCell::new([0; 256]);

    static IS_INITIALIZED: RefCell<bool> = RefCell::new(false);
}

const FROM_BYTES: &[u8] = b"wsatugcyrkmbdhvnATUGCYRKMBDHVN";
const TO_BYTES: &[u8] = b"WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

impl Revcomp {
    pub fn new() -> Self {
        let n = config_i64("CLBG::Revcomp", "n");

        Self {
            n,
            input: String::new(),
            result_val: 0,
        }
    }

    fn init_lookup_table() {
        IS_INITIALIZED.with(|initialized| {
            if *initialized.borrow() {
                return;
            }

            LOOKUP_TABLE.with(|table_cell| {
                let mut table = table_cell.borrow_mut();

                for i in 0..256 {
                    table[i] = i as u8;
                }

                for (&from, &to) in FROM_BYTES.iter().zip(TO_BYTES.iter()) {
                    table[from as usize] = to;
                }
            });

            *initialized.borrow_mut() = true;
        });
    }

    fn revcomp(seq: &str) -> String {
        Self::init_lookup_table();

        let n = seq.len();

        let mut bytes = Vec::with_capacity(n);
        bytes.extend_from_slice(seq.as_bytes());

        bytes.reverse();

        LOOKUP_TABLE.with(|table_cell| {
            let table = table_cell.borrow();
            for byte in bytes.iter_mut() {
                *byte = table[*byte as usize];
            }
        });

        let line_breaks = n / 60 + if n % 60 > 0 { 1 } else { 0 };
        let mut result = String::with_capacity(n + line_breaks);

        for chunk in bytes.chunks(60) {
            result.push_str(unsafe { std::str::from_utf8_unchecked(chunk) });
            result.push('\n');
        }

        result
    }
}

impl Benchmark for Revcomp {
    fn name(&self) -> String {
        "CLBG::Revcomp".to_string()
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
        self.result_val = self.result_val.wrapping_add(helper::checksum_str(&rev));
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}

unsafe impl Send for Revcomp {}
unsafe impl Sync for Revcomp {}
