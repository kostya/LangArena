use super::super::{Benchmark, INPUT, helper};
use serde_json::Value;

pub struct JsonParseDom {
    n: i32,
    text: String,
    result: u32,
}

impl JsonParseDom {
    pub fn new() -> Self {
        let name = "JsonParseDom".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            text: String::new(),
            result: 0,
        }
    }
    
    fn calc(&self, text: &str) -> (f64, f64, f64) {
        let json: Value = serde_json::from_str(text).unwrap();
        let coordinates = json["coordinates"].as_array().unwrap();
        let len = coordinates.len() as f64;
        
        let mut x = 0.0;
        let mut y = 0.0;
        let mut z = 0.0;
        
        for coord in coordinates {
            x += coord["x"].as_f64().unwrap();
            y += coord["y"].as_f64().unwrap();
            z += coord["z"].as_f64().unwrap();
        }
        
        (x / len, y / len, z / len)
    }
}

impl Benchmark for JsonParseDom {
    fn name(&self) -> String {
        "JsonParseDom".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn prepare(&mut self) {
        use crate::benchmarks::json_generate::JsonGenerate;
        
        let mut generator = JsonGenerate::new();
        generator.n = self.iterations();
        generator.prepare();
        generator.run();
        self.text = generator.get_text().to_string();
    }
    
    fn run(&mut self) {
        let (x, y, z) = self.calc(&self.text);
        self.result = helper::checksum_f64(x)
            .wrapping_add(helper::checksum_f64(y))
            .wrapping_add(helper::checksum_f64(z));
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}