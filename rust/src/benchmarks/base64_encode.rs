use super::super::{Benchmark, INPUT, helper};
use base64::{engine::general_purpose, Engine as _};

const TRIES: i32 = 8192;

pub struct Base64Encode {
    n: i32,
    str_data: String,
    str2_encoded: String,
    result: u32,
}

impl Base64Encode {
    pub fn new() -> Self {
        let name = "Base64Encode".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            str_data: String::new(),
            str2_encoded: String::new(),
            result: 0,
        }
    }
}

impl Benchmark for Base64Encode {
    fn name(&self) -> String {
        "Base64Encode".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn prepare(&mut self) {
        // Создаем строку из 'a' длиной n
        self.str_data = "a".repeat(self.n as usize);
        
        // Кодируем в base64
        self.str2_encoded = general_purpose::STANDARD.encode(&self.str_data);
    }
    
    fn run(&mut self) {
        let mut s_encoded: i64 = 0;
        
        for _ in 0..TRIES {
            let encoded = general_purpose::STANDARD.encode(&self.str_data);
            s_encoded += encoded.len() as i64;
        }
        
        let message = format!(
            "encode {}... to {}...: {}\n",
            &self.str_data[0..std::cmp::min(4, self.str_data.len())],
            &self.str2_encoded[0..std::cmp::min(4, self.str2_encoded.len())],
            s_encoded
        );
        
        self.result = helper::checksum_str(&message);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}