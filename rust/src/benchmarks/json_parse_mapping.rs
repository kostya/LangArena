use super::super::{Benchmark, INPUT, helper};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
struct CoordinateData {
    x: f64,
    y: f64,
    z: f64,
}

#[derive(Deserialize)]
struct Coordinates {
    coordinates: Vec<CoordinateData>,
}

#[derive(Serialize)]
struct AverageCoordinate {
    x: f64,
    y: f64,
    z: f64,
}

pub struct JsonParseMapping {
    n: i32,
    text: String,
    result: u32,
}

impl JsonParseMapping {
    pub fn new() -> Self {
        let name = "JsonParseMapping".to_string();
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
    
    fn calc(&self, text: &str) -> AverageCoordinate {
        let data: Coordinates = serde_json::from_str(text).unwrap();
        let len = data.coordinates.len() as f64;
        
        let mut x = 0.0;
        let mut y = 0.0;
        let mut z = 0.0;
        
        for coord in data.coordinates {
            x += coord.x;
            y += coord.y;
            z += coord.z;
        }
        
        AverageCoordinate {
            x: x / len,
            y: y / len,
            z: z / len,
        }
    }
}

impl Benchmark for JsonParseMapping {
    fn name(&self) -> String {
        "JsonParseMapping".to_string()
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
        let avg = self.calc(&self.text);
        self.result = helper::checksum_f64(avg.x)
            .wrapping_add(helper::checksum_f64(avg.y))
            .wrapping_add(helper::checksum_f64(avg.z));
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}