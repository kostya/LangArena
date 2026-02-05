use super::super::{Benchmark, helper};
use crate::config_i64;
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortQuick {
    base: SortBenchmark,
}

impl SortQuick {
    fn quick_sort(arr: &mut [i32]) {
        if arr.len() <= 1 {
            return;
        }

        let pivot = arr[arr.len() / 2];
        let mut i = 0;
        let mut j = arr.len() - 1;

        while i <= j {
            while arr[i] < pivot {
                i += 1;
            }
            while arr[j] > pivot {
                j -= 1;
            }
            if i <= j {
                arr.swap(i, j);
                i += 1;
                if j > 0 {
                    j -= 1;
                }
            }
        }

        if j > 0 {
            Self::quick_sort(&mut arr[0..=j]);
        }
        if i < arr.len() {
            Self::quick_sort(&mut arr[i..]);
        }
    }

    pub fn new() -> Self {
        Self {
            base: SortBenchmark::new_base(),
        }
    }
}

impl Benchmark for SortQuick {
    fn name(&self) -> String {
        "SortQuick".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("SortQuick");
    }

    fn run(&mut self, _iteration_id: i64) {

        self.base.result_val = self.base.result_val.wrapping_add(
            self.base.data[helper::next_int(self.base.size_val as i32) as usize] as u32
        );
        let mut t = self.base.data.clone();
        Self::quick_sort(&mut t);
        self.base.result_val = self.base.result_val.wrapping_add(
            t[helper::next_int(self.base.size_val as i32) as usize] as u32
        );
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}