use super::super::{Benchmark, INPUT, helper};
use rayon::ThreadPoolBuilder;
use rayon::prelude::*;

pub struct Matmul8T {
    n: i32,
    result: u32,
}

impl Matmul8T {
    pub fn new() -> Self {
        let name = "Matmul8T".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n: iterations,
            result: 0,
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
            .num_threads(8)
            .build()
            .expect("Failed to create local thread pool 8");
        
        let size = a.len();
        
        // Транспонируем b
        let mut b_t = vec![vec![0.0; size]; size];
        for i in 0..size {
            for j in 0..size {
                b_t[j][i] = b[i][j];
            }
        }
        
        // Умножение матриц
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

impl Benchmark for Matmul8T {
    fn name(&self) -> String {
        "Matmul8T".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let n = self.n as usize;
        
        let a = self.matgen(n);
        let b = self.matgen(n);
        
        let c = self.matmul_parallel(&a, &b);
        
        let center_value = c[n >> 1][n >> 1];
        self.result = helper::checksum_f64(center_value);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}