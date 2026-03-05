use super::super::{helper, Benchmark};
use crate::config_i64;
use simd_csv;
use std::fmt::Write;

#[derive(Debug, Clone, Copy)]
struct Point {
    x: f64,
    y: f64,
    z: f64,
}

pub struct CsvParse {
    rows: usize,
    checksum: u32,
    data: String,
}

impl CsvParse {
    pub fn new() -> Self {
        let rows = config_i64("CSV::Parse", "rows") as usize;
        Self {
            rows,
            checksum: 0,
            data: String::new(),
        }
    }

    fn generate_data(&mut self) {
        self.data.clear();

        for i in 0..self.rows {
            let c = (b'A' + (i % 26) as u8) as char;
            let x = helper::next_float(1.0);
            let z = helper::next_float(1.0);
            let y = helper::next_float(1.0);
            write!(&mut self.data, "\"point {c}\\n, \"\"{}\"\"\",", i % 100).unwrap();
            write!(&mut self.data, "{:.10},", x).unwrap();
            write!(&mut self.data, ",").unwrap();
            write!(&mut self.data, "{:.10},", z).unwrap();
            let flag = if i % 2 == 0 { "true" } else { "false" };
            write!(&mut self.data, "\"[{flag}\\n, {}]\",", i % 100).unwrap();
            write!(&mut self.data, "{:.10}\n", y).unwrap();
        }
    }

    fn parse_points(&self) -> Vec<Point> {
        let mut points = Vec::new();

        let mut reader = simd_csv::ZeroCopyReaderBuilder::new()
            .has_headers(false)
            .delimiter(b',')
            .quote(b'"')
            .from_reader(self.data.as_bytes());

        while let Ok(Some(record)) = reader.read_byte_record() {
            let x = std::str::from_utf8(&record[1])
                .unwrap()
                .parse::<f64>()
                .unwrap();
            let z = std::str::from_utf8(&record[3])
                .unwrap()
                .parse::<f64>()
                .unwrap();
            let y = std::str::from_utf8(&record[5])
                .unwrap()
                .parse::<f64>()
                .unwrap();

            points.push(Point { x, y, z });
        }

        points
    }
}

impl Benchmark for CsvParse {
    fn name(&self) -> String {
        "CSV::Parse".to_string()
    }

    fn prepare(&mut self) {
        self.generate_data();
    }

    fn run(&mut self, _iteration_id: i64) {
        let points = self.parse_points();

        if points.is_empty() {
            return;
        }

        let (mut x_sum, mut y_sum, mut z_sum) = (0.0, 0.0, 0.0);
        for point in &points {
            x_sum += point.x;
            y_sum += point.y;
            z_sum += point.z;
        }

        let count = points.len() as f64;
        let x_avg = x_sum / count;
        let y_avg = y_sum / count;
        let z_avg = z_sum / count;

        self.checksum = self
            .checksum
            .wrapping_add(helper::checksum_f64(x_avg))
            .wrapping_add(helper::checksum_f64(y_avg))
            .wrapping_add(helper::checksum_f64(z_avg));
    }

    fn checksum(&self) -> u32 {
        self.checksum
    }
}
