use super::super::{Benchmark, INPUT, helper};
use std::io::Write;

const ITER: i32 = 50;
const LIMIT: f64 = 2.0;

pub struct Mandelbrot {
    n: i32,
    result: Vec<u8>,
}

impl Mandelbrot {
    pub fn new() -> Self {
        let name = "Mandelbrot".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: Vec::new(),
        }
    }
}

impl Benchmark for Mandelbrot {
    fn name(&self) -> String {
        "Mandelbrot".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let w = self.n as usize;
        let h = self.n as usize;
        
        writeln!(&mut self.result, "P4\n{} {}", w, h).unwrap();
        
        let mut bit_num = 0;
        let mut byte_acc: u8 = 0;
        
        for y in 0..h {
            for x in 0..w {
                let mut zr = 0.0;
                let mut zi = 0.0;
                let mut tr = 0.0;
                let mut ti = 0.0;
                
                let cr = (2.0 * x as f64 / w as f64) - 1.5;
                let ci = (2.0 * y as f64 / h as f64) - 1.0;

                let mut i = 0;
                while i < ITER && (tr + ti) <= (LIMIT * LIMIT) {
                    zi = 2.0 * zr * zi + ci;
                    zr = tr - ti + cr;
                    tr = zr * zr;
                    ti = zi * zi;
                    i += 1;
                }
                
                byte_acc <<= 1;                
                if tr + ti <= LIMIT * LIMIT {
                    byte_acc |= 0x01;
                }
                bit_num += 1;
                
                if bit_num == 8 {                    
                    self.result.push(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                } else if x == w - 1 {
                    byte_acc <<= 8 - (w % 8);
                    self.result.push(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                }
            }
        }
    }
    
    fn result(&self) -> i64 {
        helper::checksum_bytes(&self.result) as i64
    }
}