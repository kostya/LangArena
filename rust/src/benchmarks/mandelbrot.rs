use super::super::{helper, Benchmark};
use crate::config_i64;

const ITER: i32 = 50;
const LIMIT: f64 = 2.0;

pub struct Mandelbrot {
    w: i64,
    h: i64,
    result_bin: Vec<u8>,
}

impl Mandelbrot {
    pub fn new() -> Self {
        let w = config_i64("CLBG::Mandelbrot", "w");
        let h = config_i64("CLBG::Mandelbrot", "h");

        Self {
            w,
            h,
            result_bin: Vec::new(),
        }
    }
}

impl Benchmark for Mandelbrot {
    fn name(&self) -> String {
        "CLBG::Mandelbrot".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let w = self.w as usize;
        let h = self.h as usize;

        let header = format!("P4\n{} {}\n", w, h);
        self.result_bin.extend_from_slice(header.as_bytes());

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
                    self.result_bin.push(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                } else if x == w - 1 {
                    byte_acc <<= 8 - (w % 8);
                    self.result_bin.push(byte_acc);
                    byte_acc = 0;
                    bit_num = 0;
                }
            }
        }
    }

    fn checksum(&self) -> u32 {
        helper::checksum_bytes(&self.result_bin)
    }
}
