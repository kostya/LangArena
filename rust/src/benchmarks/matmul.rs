use super::super::{helper, Benchmark};
use crate::config_i64;
use rayon::prelude::*;
use rayon::ThreadPoolBuilder;

fn matgen(n: usize) -> Vec<Vec<f64>> {
    let tmp = 1.0 / (n * n) as f64;
    let mut a = vec![vec![0.0; n]; n];

    for i in 0..n {
        for j in 0..n {
            a[i][j] = tmp * (i as f64 - j as f64) * (i as f64 + j as f64);
        }
    }

    a
}

fn transpose(b: &[Vec<f64>]) -> Vec<Vec<f64>> {
    let n = b.len();
    let mut b_t = vec![vec![0.0; n]; n];

    for i in 0..n {
        for j in 0..n {
            b_t[j][i] = b[i][j];
        }
    }

    b_t
}

fn matmul_sequential(a: &[Vec<f64>], b: &[Vec<f64>]) -> Vec<Vec<f64>> {
    let n = a.len();
    let b_t = transpose(b);

    let mut c = vec![vec![0.0; n]; n];

    for i in 0..n {
        let a_row = &a[i];
        let c_row = &mut c[i];

        for j in 0..n {
            let b_col = &b_t[j];
            let mut s = 0.0;

            for k in 0..n {
                s += a_row[k] * b_col[k];
            }

            c_row[j] = s;
        }
    }

    c
}

fn matmul_parallel(a: &[Vec<f64>], b: &[Vec<f64>], num_threads: usize) -> Vec<Vec<f64>> {
    let pool = ThreadPoolBuilder::new()
        .num_threads(num_threads)
        .build()
        .expect("Failed to create thread pool");

    let n = a.len();
    let b_t = transpose(b);

    let mut c = vec![vec![0.0; n]; n];

    pool.install(|| {
        c.par_iter_mut().enumerate().for_each(|(i, c_row)| {
            let a_row = &a[i];

            for j in 0..n {
                let b_col = &b_t[j];
                let mut s = 0.0;

                for k in 0..n {
                    s += a_row[k] * b_col[k];
                }

                c_row[j] = s;
            }
        });
    });

    c
}

struct BaseMatmul {
    n: i64,
    a: Vec<Vec<f64>>,
    b: Vec<Vec<f64>>,
    result_val: u32,
}

impl BaseMatmul {
    fn new(name: &str, _num_threads: Option<usize>) -> Self {
        let n = config_i64(name, "n") as usize;
        let a = matgen(n);
        let b = matgen(n);

        Self {
            n: n as i64,
            a,
            b,
            result_val: 0,
        }
    }
}

pub struct Matmul1T {
    base: BaseMatmul,
}

impl Matmul1T {
    pub fn new() -> Self {
        Self {
            base: BaseMatmul::new("Matmul::Single", None),
        }
    }
}

impl Benchmark for Matmul1T {
    fn name(&self) -> String {
        "Matmul::Single".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let c = matmul_sequential(&self.base.a, &self.base.b);
        let center_value = c[(self.base.n >> 1) as usize][(self.base.n >> 1) as usize];
        self.base.result_val = self
            .base
            .result_val
            .wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}

pub struct Matmul4T {
    base: BaseMatmul,
}

impl Matmul4T {
    pub fn new() -> Self {
        Self {
            base: BaseMatmul::new("Matmul::T4", Some(4)),
        }
    }
}

impl Benchmark for Matmul4T {
    fn name(&self) -> String {
        "Matmul::T4".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let c = matmul_parallel(&self.base.a, &self.base.b, 4);
        let center_value = c[(self.base.n >> 1) as usize][(self.base.n >> 1) as usize];
        self.base.result_val = self
            .base
            .result_val
            .wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}

pub struct Matmul8T {
    base: BaseMatmul,
}

impl Matmul8T {
    pub fn new() -> Self {
        Self {
            base: BaseMatmul::new("Matmul::T8", Some(8)),
        }
    }
}

impl Benchmark for Matmul8T {
    fn name(&self) -> String {
        "Matmul::T8".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let c = matmul_parallel(&self.base.a, &self.base.b, 8);
        let center_value = c[(self.base.n >> 1) as usize][(self.base.n >> 1) as usize];
        self.base.result_val = self
            .base
            .result_val
            .wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}

pub struct Matmul16T {
    base: BaseMatmul,
}

impl Matmul16T {
    pub fn new() -> Self {
        Self {
            base: BaseMatmul::new("Matmul::T16", Some(16)),
        }
    }
}

impl Benchmark for Matmul16T {
    fn name(&self) -> String {
        "Matmul::T16".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let c = matmul_parallel(&self.base.a, &self.base.b, 16);
        let center_value = c[(self.base.n >> 1) as usize][(self.base.n >> 1) as usize];
        self.base.result_val = self
            .base
            .result_val
            .wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}
