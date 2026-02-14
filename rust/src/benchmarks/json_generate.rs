use super::super::{Benchmark, helper};
use crate::config_i64;
use serde::{Serialize, Deserialize};
use serde_json;
use std::collections::HashMap;

type OptsMap = HashMap<String, (i32, bool)>;

#[derive(Serialize, Deserialize, Clone)]
struct Coordinate {
    x: f64,
    y: f64,
    z: f64,
    name: String,
    opts: OptsMap,
}

#[derive(Serialize)]
struct JsonData {
    coordinates: Vec<Coordinate>,
    info: &'static str,
}

pub struct JsonGenerate {
    pub(crate) n: i64,
    text: String,
    data: JsonData,
    result: u32,
}

impl JsonGenerate {
    pub fn new() -> Self {
        let n = config_i64("JsonGenerate", "coords");

        Self {
            n,
            text: String::new(),
            data: JsonData{coordinates: Vec::new(), info: "some info"},
            result: 0,
        }
    }

    fn round_to_8(value: f64) -> f64 {
        (value * 100_000_000.0).round() / 100_000_000.0
    }

    pub fn get_result(&self) -> &str {
        &self.text
    }
}

impl Benchmark for JsonGenerate {
    fn name(&self) -> String {
        "JsonGenerate".to_string()
    }

    fn prepare(&mut self) {
        let mut data = Vec::new();
        for _ in 0..self.n {

            let x = Self::round_to_8(helper::next_float(1.0));
            let y = Self::round_to_8(helper::next_float(1.0));
            let z = Self::round_to_8(helper::next_float(1.0));

            let name = format!("{:.7} {}", helper::next_float(1.0), helper::next_int(10000));

            let mut opts = HashMap::new();
            opts.insert("1".to_string(), (1, true));

            data.push(Coordinate {
                x,
                y,
                z,
                name,
                opts,
            });
        }
        let json_data = JsonData {
            coordinates: data,
            info: "some info",
        };
        self.data = json_data;
    }

    fn run(&mut self, _iteration_id: i64) {
        self.text = serde_json::to_string(&self.data).unwrap();
        if self.text.starts_with("{\"coordinates\":") {
            self.result += 1;
        }
    }

    fn checksum(&self) -> u32 {
        self.result
    }
}