use super::super::{Benchmark, INPUT, helper};
use serde::{Serialize, Deserialize};
use serde_json;

#[derive(Serialize, Deserialize, Clone)]
struct Opts {
    _1: (i32, bool),
}

impl Opts {
    fn new() -> Self {
        Self {
            _1: (1, true),
        }
    }
}

#[derive(Serialize, Deserialize, Clone)]
struct Coordinate {
    x: f64,
    y: f64,
    z: f64,
    name: String,
    opts: Opts,
}

#[derive(Serialize)]
struct JsonData {
    coordinates: Vec<Coordinate>,
    info: &'static str,
}

pub struct JsonGenerate {
    pub(crate) n: i32,
    text: String,
    data: Vec<Coordinate>,
}

impl JsonGenerate {
    pub fn new() -> Self {
        let name = "JsonGenerate".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);  
        Self {
            n: iterations,
            text: String::new(),
            data: Vec::new(),
        }
    }
    
    // Публичный метод для получения сгенерированного JSON
    pub fn get_text(&self) -> &str {
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
            data.push(Coordinate {
                x: (helper::next_float(1.0) * 1_000_000.0).round() / 1_000_000.0, // round to 6 decimal places
                y: (helper::next_float(1.0) * 1_000_000.0).round() / 1_000_000.0,
                z: (helper::next_float(1.0) * 1_000_000.0).round() / 1_000_000.0,
                name: format!("{:.7} {}", helper::next_float(1.0), helper::next_int(10_000)),
                opts: Opts::new(),
            });
        }
        self.data = data;
    }

    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let json_data = JsonData {
            coordinates: self.data.clone(), // TODO: probably clone take some time, move it to prepare
            info: "some info",
        };
        
        self.text = serde_json::to_string(&json_data).unwrap();
    }
    
    fn result(&self) -> i64 {
        // Как в оригинале - всегда возвращаем 1, потому что проверка делается при парсинге
        1
    }
}