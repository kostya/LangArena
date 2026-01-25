use super::super::{Benchmark, INPUT};
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortSelf {
    base: SortBenchmark,
}

impl SortSelf {
    pub fn new() -> Self {
        let name = "SortSelf".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            base: SortBenchmark::new_base(iterations),
        }
    }
}

impl Benchmark for SortSelf {
    fn name(&self) -> String {
        "SortSelf".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.base.n
    }
    
    fn prepare(&mut self) {
        self.base.prepare_common();
    }
    
    fn run(&mut self) {
        let data = self.base.data.clone();
        self.base.run_common(|| {
            let mut arr = data.clone();
            arr.sort();
            arr
        });
    }
    
    fn result(&self) -> i64 {
        self.base.result as i64
    }
}