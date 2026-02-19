use super::super::{helper, Benchmark};
use crate::config_i64;

pub struct Matmul1T {
    n: i64,
    result_val: u32,
}

impl Matmul1T {
    pub fn new() -> Self {
        let n = config_i64("Matmul1T", "n");

        Self { n, result_val: 0 }
    }

    fn matmul(&self, a: &[Vec<f64>], b: &[Vec<f64>]) -> Vec<Vec<f64>> {
        let m = a.len();
        let n = a[0].len();
        let p = b[0].len();

        let mut b2 = vec![vec![0.0; n]; p];
        for i in 0..n {
            for j in 0..p {
                b2[j][i] = b[i][j];
            }
        }

        let mut c = vec![vec![0.0; p]; m];
        for i in 0..m {
            let ai = &a[i];
            let ci = &mut c[i];

            for j in 0..p {
                let mut s = 0.0;
                let b2j = &b2[j];

                for k in 0..n {
                    s += ai[k] * b2j[k];
                }

                ci[j] = s;
            }
        }

        c
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
}

impl Benchmark for Matmul1T {
    fn name(&self) -> String {
        "Matmul1T".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let n = self.n as usize;
        let a = self.matgen(n);
        let b = self.matgen(n);
        let c = self.matmul(&a, &b);

        let center_value = c[n >> 1][n >> 1];
        self.result_val = self
            .result_val
            .wrapping_add(helper::checksum_f64(center_value));
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}
