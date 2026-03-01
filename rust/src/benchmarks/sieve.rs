use super::super::Benchmark;
use crate::config_i64;

pub struct Sieve {
    limit: i64,
    checksum: u32,
}

impl Sieve {
    pub fn new() -> Self {
        let limit = config_i64("Etc::Sieve", "limit");
        Self { limit, checksum: 0 }
    }
}

impl Benchmark for Sieve {
    fn name(&self) -> String {
        "Etc::Sieve".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let limit = self.limit as usize;

        let mut primes = vec![1u8; limit + 1];
        primes[0] = 0;
        primes[1] = 0;

        let sqrt_limit = (limit as f64).sqrt() as usize;

        for p in 2..=sqrt_limit {
            if primes[p] == 1 {
                let mut multiple = p * p;
                while multiple <= limit {
                    primes[multiple] = 0;
                    multiple += p;
                }
            }
        }

        let mut last_prime = 2;
        let mut count = 1;

        let mut n = 3;
        while n <= limit {
            if primes[n] == 1 {
                last_prime = n;
                count += 1;
            }
            n += 2;
        }

        self.checksum = self.checksum.wrapping_add((last_prime + count) as u32);
    }

    fn checksum(&self) -> u32 {
        self.checksum
    }
}
