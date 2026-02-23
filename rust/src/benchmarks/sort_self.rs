use super::super::{helper, Benchmark};
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortSelf {
    base: SortBenchmark,
}

impl SortSelf {
    pub fn new() -> Self {
        Self {
            base: SortBenchmark::new_base(),
        }
    }
}

impl Benchmark for SortSelf {
    fn name(&self) -> String {
        "Sort::Self".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("Sort::Self");
    }

    fn run(&mut self, _iteration_id: i64) {
        self.base.result_val = self.base.result_val.wrapping_add(
            self.base.data[helper::next_int(self.base.size_val as i32) as usize] as u32,
        );
        let mut t = self.base.data.clone();
        t.sort();
        self.base.result_val = self
            .base
            .result_val
            .wrapping_add(t[helper::next_int(self.base.size_val as i32) as usize] as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}
