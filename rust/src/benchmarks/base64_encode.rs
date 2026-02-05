use super::super::{Benchmark, helper};
use crate::config_i64;
use base64::{engine::general_purpose, Engine as _};

pub struct Base64Encode {
    n: i64,
    str_data: String,
    str2_encoded: String,
    result_val: u32,
}

impl Base64Encode {
    pub fn new() -> Self {
        let n = config_i64("Base64Encode", "size");

        let str_data = "a".repeat(n as usize);

        let str2_encoded = general_purpose::STANDARD.encode(&str_data);

        Self {
            n,
            str_data,
            str2_encoded,
            result_val: 0,
        }
    }
}

impl Benchmark for Base64Encode {
    fn name(&self) -> String {
        "Base64Encode".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {

        let encoded = general_purpose::STANDARD.encode(&self.str_data);
        self.result_val = self.result_val.wrapping_add(encoded.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let message = format!(
            "encode {} to {}: {}",
            if self.str_data.len() > 4 { format!("{}...", &self.str_data[0..4]) } else { self.str_data.clone() },
            if self.str2_encoded.len() > 4 { format!("{}...", &self.str2_encoded[0..4]) } else { self.str2_encoded.clone() },
            self.result_val
        );

        helper::checksum_str(&message)
    }
}