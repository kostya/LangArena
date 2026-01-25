use super::super::{Benchmark, INPUT, helper};
use base64::{engine::general_purpose, Engine as _};

const TRIES: i32 = 8192;

pub struct Base64Decode {
    n: i32,
    str2_encoded: String,
    str3_decoded: String,
    result: u32,
}

impl Base64Decode {
    pub fn new() -> Self {
        let name = "Base64Decode".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            str2_encoded: String::new(),
            str3_decoded: String::new(),
            result: 0,
        }
    }
}

impl Benchmark for Base64Decode {
    fn name(&self) -> String {
        "Base64Decode".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn prepare(&mut self) {
        // Создаем строку из 'a' длиной n
        let str_data = "a".repeat(self.n as usize);
        
        // Кодируем в base64
        self.str2_encoded = general_purpose::STANDARD.encode(&str_data);
        
        // Декодируем обратно
        self.str3_decoded = String::from_utf8(
            general_purpose::STANDARD.decode(&self.str2_encoded).unwrap()
        ).unwrap();
    }
    
    fn run(&mut self) {
        let mut s_decoded: i64 = 0;
        
        for _ in 0..TRIES {
            let decoded = general_purpose::STANDARD.decode(&self.str2_encoded).unwrap();
            s_decoded += decoded.len() as i64;
        }
        
        let message = format!(
            "decode {}... to {}...: {}\n",
            &self.str2_encoded[0..std::cmp::min(4, self.str2_encoded.len())],
            &self.str3_decoded[0..std::cmp::min(4, self.str3_decoded.len())],
            s_decoded
        );
        
        self.result = helper::checksum_str(&message);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}