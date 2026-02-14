use super::super::{Benchmark, helper};
use crate::config_i64;

pub struct Spectralnorm {
    size_val: i64,
    u: Vec<f64>,
    v: Vec<f64>,
    result_val: u32,
}

impl Spectralnorm {
    pub fn new() -> Self {
        let size_val = config_i64("Spectralnorm", "size");

        Self {
            size_val,
            u: vec![1.0; size_val as usize],
            v: vec![1.0; size_val as usize],
            result_val: 0,
        }
    }

    fn eval_a(&self, i: usize, j: usize) -> f64 {

        let ij = (i + j) as f64;
        1.0 / (ij * (ij + 1.0) / 2.0 + i as f64 + 1.0)
    }

    fn eval_a_times_u(&self, u: &[f64]) -> Vec<f64> {
        let n = u.len();
        let mut result = vec![0.0; n];

        let u_slice = u;

        for (i, r) in result.iter_mut().enumerate() {
            *r = u_slice.iter()
                .enumerate()
                .map(|(j, &u)| self.eval_a(i, j) * u)
                .sum();
        }

        result
    }

    fn eval_at_times_u(&self, u: &[f64]) -> Vec<f64> {
        let n = u.len();
        let mut result = vec![0.0; n];

        let u_slice = u;

        for (i, r) in result.iter_mut().enumerate() {
            *r = u_slice.iter()
                .enumerate()
                .map(|(j, &u)| self.eval_a(j, i) * u)
                .sum();
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

    fn run(&mut self, _iteration_id: i64) {
        self.v = self.eval_ata_times_u(&self.u);
        self.u = self.eval_ata_times_u(&self.v);
    }

    fn checksum(&self) -> u32 {
        let mut vbv = 0.0;
        let mut vv = 0.0;

        for i in 0..(self.size_val as usize) {
            let vi = self.v[i];
            vbv += self.u[i] * vi;
            vv += vi * vi;
        }

        let result_value = (vbv / vv).sqrt();
        helper::checksum_f64(result_value)
    }
}