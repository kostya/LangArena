use super::super::{helper, Benchmark};
use crate::config_i64;
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

pub struct JsonParseMapping {
    n: i64,
    text: String,
    result_val: u32,
}

impl JsonParseMapping {
    pub fn new() -> Self {
        let n = config_i64("JsonParseMapping", "coords");

        Self {
            n,
            text: String::new(),
            result_val: 0,
        }
    }

    fn calc(&self, text: &str) -> CoordinateData {
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

        CoordinateData {
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

    fn prepare(&mut self) {
        use crate::benchmarks::json_generate::JsonGenerate;

        let mut generator = JsonGenerate::new();
        generator.n = self.n;
        generator.prepare();
        generator.run(0);
        self.text = generator.get_result().to_string();
    }

    fn run(&mut self, _iteration_id: i64) {
        let avg = self.calc(&self.text);
        self.result_val = self.result_val.wrapping_add(
            helper::checksum_f64(avg.x)
                .wrapping_add(helper::checksum_f64(avg.y))
                .wrapping_add(helper::checksum_f64(avg.z)),
        );
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
