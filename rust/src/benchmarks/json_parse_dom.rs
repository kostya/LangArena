use super::super::{helper, Benchmark};
use crate::config_i64;
use serde_json::Value;

pub struct JsonParseDom {
    n: i64,
    text: String,
    result_val: u32,
}

impl JsonParseDom {
    pub fn new() -> Self {
        let n = config_i64("Json::ParseDom", "coords");

        Self {
            n,
            text: String::new(),
            result_val: 0,
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
        "Json::ParseDom".to_string()
    }

    fn prepare(&mut self) {
        use crate::benchmarks::json_generate::JsonGenerate;

        let mut generator = JsonGenerate::new();
        generator.n = self.n;
        generator.prepare();
        generator.run(0);
        self.text = generator.get_result().to_string();
    }

    fn run(&mut self, _iteration_id: i64) {
        let (x, y, z) = self.calc(&self.text);
        self.result_val = self.result_val.wrapping_add(
            helper::checksum_f64(x)
                .wrapping_add(helper::checksum_f64(y))
                .wrapping_add(helper::checksum_f64(z)),
        );
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
