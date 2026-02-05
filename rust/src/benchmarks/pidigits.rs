use super::super::{Benchmark, helper};
use super::super::config_i64;
use num_bigint::BigInt;
use num_traits::{Zero, One, FromPrimitive};
use std::io::Write;

pub struct Pidigits {
    nn: i32,
    result: Vec<u8>,
}

impl Pidigits {
    pub fn new() -> Self {
        let nn = config_i64("Pidigits", "amount") as i32;

        Self {
            nn,
            result: Vec::new(),
        }
    }
}

impl Benchmark for Pidigits {
    fn name(&self) -> String {
        "Pidigits".to_string()
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut i = 0;
        let mut k = 0;
        let mut ns = BigInt::zero();
        let mut a = BigInt::zero();
        let mut k1 = 1;
        let mut n = BigInt::one();
        let mut d = BigInt::one();

        let ten = BigInt::from_u8(10).unwrap();
        let three = BigInt::from_u8(3).unwrap();

        loop {
            k += 1;
            let t = &n << 1; 
            n = &n * k;
            k1 += 2;
            a = (&a + &t) * k1;
            d = &d * k1;

            if a >= n {
                let temp = &n * &three + &a;
                let (t, u) = (&temp / &d, &temp % &d);
                let u = u + &n;

                if d > u {
                    ns = &ns * &ten + &t;
                    i += 1;

                    if i % 10 == 0 {
                        let ns_u64: u64 = ns.to_u64_digits().1
                            .first()
                            .copied()
                            .unwrap_or(0);
                        write!(&mut self.result, "{:010}\t:{}", ns_u64, i).unwrap();
                        writeln!(&mut self.result).unwrap();
                        ns = BigInt::zero();
                    }

                    if i >= self.nn {
                        break;
                    }

                    a = (&a - (&d * &t)) * &ten;
                    n = &n * &ten;
                }
            }
        }

        if i % 10 != 0 {
            let digits_needed = 10 - (i % 10);
            let ns_u64: u64 = (&ns * BigInt::from_u64(10u64.pow(digits_needed as u32)).unwrap())
                .to_u64_digits().1
                .first()
                .copied()
                .unwrap_or(0);
            write!(&mut self.result, "{:0width$}\t:{}", ns_u64, i, width = 10).unwrap();
        }
    }

    fn checksum(&self) -> u32 {
        let result_str = String::from_utf8_lossy(&self.result);
        return helper::checksum_str(&result_str);
    }
}