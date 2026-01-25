use super::super::{Benchmark, INPUT, helper};

pub struct Matmul {
    n: i32,
    result: u32,
}

impl Matmul {
    pub fn new() -> Self {
        let name = "Matmul".to_string();
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

    fn matmul(&self, a: &[Vec<f64>], b: &[Vec<f64>]) -> Vec<Vec<f64>> {
        let m = a.len();
        let n = a[0].len();
        let p = b[0].len();
        
        // transpose b
        let mut b2 = vec![vec![0.0; n]; p];
        for i in 0..n {
            for j in 0..p {
                b2[j][i] = b[i][j];
            }
        }
        
        // multiplication
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

impl Benchmark for Matmul {
    fn name(&self) -> String {
        "Matmul".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let n = self.n as usize;
        let a = self.matgen(n);
        let b = self.matgen(n);
        let c = self.matmul(&a, &b);
        
        let center_value = c[n >> 1][n >> 1];
        self.result = helper::checksum_f64(center_value);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}