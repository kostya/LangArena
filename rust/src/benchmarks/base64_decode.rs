use super::super::{helper, Benchmark};
use crate::config_i64;
use base64::{engine::general_purpose, Engine as _};

pub struct Base64Decode {
    n: i64,
    str2_encoded: String,
    str3_decoded: Vec<u8>,
    result_val: u32,
}

impl Base64Decode {
    pub fn new() -> Self {
        let n = config_i64("Base64Decode", "size");
        let str_data = "a".repeat(n as usize);
        let str2_encoded = general_purpose::STANDARD.encode(&str_data);
        let str3_decoded = general_purpose::STANDARD.decode(&str2_encoded).unwrap();

        Self {
            n,
            str2_encoded,
            str3_decoded,
            result_val: 0,
        }
    }
}

impl Benchmark for Base64Decode {
    fn name(&self) -> String {
        "Base64Decode".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        self.str3_decoded = general_purpose::STANDARD
            .decode(&self.str2_encoded)
            .unwrap();
        self.result_val = self.result_val.wrapping_add(self.str3_decoded.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let slice = &self.str3_decoded[0..4];
        let str3 = String::from(std::str::from_utf8(slice).unwrap());

        let message = format!(
            "decode {} to {}: {}",
            if self.str2_encoded.len() > 4 {
                format!("{}...", &self.str2_encoded[0..4])
            } else {
                self.str2_encoded.clone()
            },
            format!("{}...", &str3[0..4]),
            self.result_val
        );

        helper::checksum_str(&message)
    }
}
