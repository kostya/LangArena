use super::super::{Benchmark, helper};
use crate::config_i64;
use rayon::ThreadPoolBuilder;
use rayon::prelude::*;

pub struct Matmul4T {
    n: i64,
    result_val: u32,
}

impl Matmul4T {
    pub fn new() -> Self {
        let n = config_i64("Matmul4T", "n");

        Self {
            n,
            result_val: 0,
        }
    }

    fn matgen(&self, n: usize) -> Vec<Vec<f64>> {
        let tmp = 1.0 / (n * n) as f64;
        let mut a = vec![vec![0.0; n]; n];

        for i in 0..n {
            for j in 0..n {
                a[i][j] = tmp * (i as f64 - j as f64) * (i as f64 + j as f64);
            }
        }

        a
    }

    fn matmul_parallel(&self, a: &[Vec<f64>], b: &[Vec<f64>]) -> Vec<Vec<f64>> {
        let pool = ThreadPoolBuilder::new()
            .num_threads(4)
            .build()
            .expect("Failed to create local thread pool 4");

        let size = a.len();

        let mut b_t = vec![vec![0.0; size]; size];
        for i in 0..size {
            for j in 0..size {
                b_t[j][i] = b[i][j];
            }
        }

        let mut c = vec![vec![0.0; size]; size];

        pool.install(|| {
            c.par_iter_mut().enumerate().for_each(|(i, ci)| {
                let ai = &a[i];
                for j in 0..size {
                    let mut sum = 0.0;
                    let b_tj = &b_t[j];

                    for k in 0..size {
                        sum += ai[k] * b_tj[k];
                    }

                    ci[j] = sum;
                }
            });
        });

        c
    }
}

impl Benchmark for Matmul4T {
    fn name(&self) -> String {
        "Matmul4T".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let n = self.n as usize;

        let a = self.matgen(n);
        let b = self.matgen(n);

        let c = self.matmul_parallel(&a, &b);

        let center_value = c[n >> 1][n >> 1];
        self.result_val = self.result_val.wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}