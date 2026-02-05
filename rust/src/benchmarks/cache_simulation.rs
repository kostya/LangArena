use super::super::{Benchmark, helper};
use crate::config_i64;
use lru::LruCache;
use std::num::NonZeroUsize;

pub struct CacheSimulation {
    operations: i32,
    result_val: u32,
    values_size: i32,
    cache_size: i32,
    cache: LruCache<String, String>,
    hits: i32,
    misses: i32,
}

impl CacheSimulation {
    pub fn new() -> Self {
        let values_size = config_i64("CacheSimulation", "values") as i32;
        let cache_size = config_i64("CacheSimulation", "size") as i32;

        Self {
            operations: 0,
            result_val: 5432,
            values_size,
            cache_size,
            cache: LruCache::new(NonZeroUsize::new(1).unwrap()), 
            hits: 0,
            misses: 0,
        }
    }
}

impl Benchmark for CacheSimulation {
    fn name(&self) -> String {
        "CacheSimulation".to_string()
    }

    fn prepare(&mut self) {
        let capacity = NonZeroUsize::new(self.cache_size as usize).unwrap();
        self.cache = LruCache::new(capacity);
        self.hits = 0;
        self.misses = 0;
    }

    fn run(&mut self, iteration_id: i64) {
        let key = format!("item_{}", helper::next_int(self.values_size));

        if self.cache.contains(&key) {
            self.hits += 1;
            let val = format!("updated_{}", iteration_id);
            self.cache.put(key, val);
        } else {
            self.misses += 1;
            let val = format!("new_{}", iteration_id);
            self.cache.put(key, val);
        }
    }

    fn checksum(&self) -> u32 {
        let mut final_result = self.result_val;
        final_result = (final_result << 5) + self.hits as u32;
        final_result = (final_result << 5) + self.misses as u32;
        final_result = (final_result << 5) + self.cache.len() as u32;
        final_result
    }
}