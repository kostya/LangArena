use super::super::{Benchmark, helper};
use super::super::config_i64;
use num_bigint::BigInt;
use num_traits::{Zero, One, FromPrimitive};
use std::fmt::Write;

pub struct Pidigits {
    nn: i32,
    result: String,
}

impl Pidigits {
    pub fn new() -> Self {
        Self {
            nn: config_i64("Pidigits", "amount") as i32,
            result: String::new(),
        }
    }
}

impl Benchmark for Pidigits {
    fn name(&self) -> String { "Pidigits".to_string() }

    fn run(&mut self, _iteration_id: i64) {
        let (mut i, mut k, mut k1) = (0, 0, 1);
        let (mut ns, mut a, mut n, mut d) = 
            (BigInt::zero(), BigInt::zero(), BigInt::one(), BigInt::one());
        let (ten, three) = (BigInt::from_u8(10).unwrap(), BigInt::from_u8(3).unwrap());

        loop {
            k += 1;
            let t = &n << 1;
            n *= k;
            k1 += 2;
            a = (&a + &t) * k1;
            d *= k1;

            if a >= n {
                let temp = &n * &three + &a;
                let (q, r) = (&temp / &d, &temp % &d);
                if d > r + &n {
                    ns = &ns * &ten + &q;
                    i += 1;

                    if i % 10 == 0 {
                        let ns_str = ns.to_str_radix(10);
                        let _ = writeln!(&mut self.result, "{:0>10}\t:{}", ns_str, i);
                        ns = BigInt::zero();
                    }

                    if i >= self.nn { break; }

                    a = (&a - (&d * &q)) * &ten;
                    n *= &ten;
                }
            }
        }
    }

    fn checksum(&self) -> u32 {
        helper::checksum_str(&self.result)
    }
}