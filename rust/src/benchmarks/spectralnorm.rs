use super::super::{Benchmark, INPUT, helper};

pub struct Spectralnorm {
    n: i32,
    result: u32,
}

impl Spectralnorm {
    pub fn new() -> Self {
        let name = "Spectralnorm".to_string();
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

    fn eval_a(&self, i: usize, j: usize) -> f64 {
        // ТОЧНО как в C++: (i + j) как целые числа, потом в float
        let ij = (i + j) as f64;
        1.0 / (ij * (ij + 1.0) / 2.0 + i as f64 + 1.0)
    }

    fn eval_a_times_u(&self, u: &[f64]) -> Vec<f64> {
        let n = u.len();
        let mut result = vec![0.0; n];
        
        // Используем slice для быстрого доступа
        let u_slice = u;
        
        for i in 0..n {
            let mut sum = 0.0;
            // Внутренний цикл - основной hot spot
            for j in 0..n {
                sum += self.eval_a(i, j) * u_slice[j];
            }
            result[i] = sum;
        }
        
        result
    }

    fn eval_at_times_u(&self, u: &[f64]) -> Vec<f64> {
        let n = u.len();
        let mut result = vec![0.0; n];
        
        let u_slice = u;
        
        // Обратите внимание: eval_a(j, i) вместо eval_a(i, j)
        for i in 0..n {
            let mut sum = 0.0;
            for j in 0..n {
                sum += self.eval_a(j, i) * u_slice[j];
            }
            result[i] = sum;
        }
        
        result
    }

    fn eval_ata_times_u(&self, u: &[f64]) -> Vec<f64> {
        let temp = self.eval_a_times_u(u);
        self.eval_at_times_u(&temp)
    }
}

impl Benchmark for Spectralnorm {
    fn name(&self) -> String {
        "Spectralnorm".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let n = self.n as usize;
        let mut u = vec![1.0; n];
        let mut v = vec![1.0; n];
        
        // ТОЧНО 10 итераций как в C++
        for _ in 0..10 {
            v = self.eval_ata_times_u(&u);
            u = self.eval_ata_times_u(&v);
        }
        
        let mut vbv = 0.0;
        let mut vv = 0.0;
        
        // Ручное объединение циклов как в C++
        for i in 0..n {
            let vi = v[i];
            vbv += u[i] * vi;
            vv += vi * vi;
        }
        
        let result_value = (vbv / vv).sqrt();
        self.result = helper::checksum_f64(result_value);
    }
    
    fn result(&self) -> i64 {
        self.result as i64
    }
}