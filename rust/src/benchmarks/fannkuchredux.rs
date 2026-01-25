use crate::{Benchmark, INPUT};

pub struct Fannkuchredux {
    n: i32,
    result: i64,
}

impl Fannkuchredux {
    pub fn new() -> Self {
        let name = "Fannkuchredux".to_string();
        let n = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            n,
            result: 0,
        }
    }

    fn fannkuchredux(&self, n: i32) -> (i32, i32) {
        let mut perm1 = [0; 32];
        for i in 0..32 {
            perm1[i] = i as i32;
        }
        
        let mut perm = [0; 32];
        let mut count = [0; 32];
        let mut max_flips_count = 0;
        let mut perm_count = 0;
        let mut checksum = 0;
        let mut r = n as usize;

        loop {
            while r > 1 {
                count[r - 1] = r as i32;
                r -= 1;
            }

            // Копируем perm1 в perm
            perm[..n as usize].copy_from_slice(&perm1[..n as usize]);
            
            let mut flips_count = 0;
            let mut k = perm[0];

            while k != 0 {
                let k2 = (k + 1) >> 1;
                for i in 0..k2 as usize {
                    let j = k as usize - i;
                    perm.swap(i, j);
                }
                flips_count += 1;
                k = perm[0];
            }

            if flips_count > max_flips_count {
                max_flips_count = flips_count;
            }
            
            if perm_count % 2 == 0 {
                checksum += flips_count;
            } else {
                checksum -= flips_count;
            }

            loop {
                if r == n as usize {
                    return (checksum, max_flips_count);
                }

                let perm0 = perm1[0];
                for i in 0..r {
                    let j = i + 1;
                    perm1.swap(i, j);
                }

                perm1[r] = perm0;
                count[r] -= 1;
                if count[r] > 0 {
                    break;
                }
                r += 1;
            }
            
            perm_count += 1;
        }
    }
}

impl Benchmark for Fannkuchredux {
    fn name(&self) -> String {
        "Fannkuchredux".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.n
    }
    
    fn run(&mut self) {
        let (checksum, max_flips) = self.fannkuchredux(self.n);
        // Как в Crystal: a.to_i64 * 100 &+ b
        self.result = (checksum as i64).wrapping_mul(100).wrapping_add(max_flips as i64);
    }
    
    fn result(&self) -> i64 {
        self.result
    }
}