use super::super::{Benchmark, INPUT};
use crate::benchmarks::buffer_hash_benchmark::BufferHashBenchmark;

fn crc32(data: &[u8]) -> u32 {
    let mut crc = 0xFFFFFFFFu32;
    
    for &byte in data {
        crc ^= byte as u32;
        for _ in 0..8 {
            if (crc & 1) != 0 {
                crc = (crc >> 1) ^ 0xEDB88320u32;
            } else {
                crc >>= 1;
            }
        }
    }
    
    crc ^ 0xFFFFFFFFu32
}

pub struct BufferHashCRC32 {
    base: BufferHashBenchmark,
}

impl BufferHashCRC32 {
    pub fn new() -> Self {
        let name = "BufferHashCRC32".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            base: BufferHashBenchmark::new_base(iterations),
        }
    }
}

impl Benchmark for BufferHashCRC32 {
    fn name(&self) -> String {
        "BufferHashCRC32".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.base.n
    }
    
    fn prepare(&mut self) {
        self.base.prepare_common();
    }
    
    fn run(&mut self) {
        self.base.run_common(crc32);
    }
    
    fn result(&self) -> i64 {
        self.base.result as i64
    }
}