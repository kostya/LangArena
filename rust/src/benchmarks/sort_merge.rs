use super::super::{Benchmark, helper};
use crate::benchmarks::sort_benchmark::SortBenchmark;

pub struct SortMerge {
    base: SortBenchmark,
}

impl SortMerge {
    fn merge_sort_inplace(arr: &mut [i32]) {
        let mut temp = vec![0; arr.len()];
        Self::merge_sort_helper(arr, &mut temp, 0, arr.len() as isize - 1);
    }

    fn merge_sort_helper(arr: &mut [i32], temp: &mut [i32], left: isize, right: isize) {
        if left >= right {
            return;
        }

        let mid = (left + right) / 2;
        Self::merge_sort_helper(arr, temp, left, mid);
        Self::merge_sort_helper(arr, temp, mid + 1, right);
        Self::merge(arr, temp, left, mid, right);
    }

    fn merge(arr: &mut [i32], temp: &mut [i32], left: isize, mid: isize, right: isize) {

        for i in left..=right {
            temp[i as usize] = arr[i as usize];
        }

        let mut i = left;    
        let mut j = mid + 1; 
        let mut k = left;    

        while i <= mid && j <= right {
            if temp[i as usize] <= temp[j as usize] {
                arr[k as usize] = temp[i as usize];
                i += 1;
            } else {
                arr[k as usize] = temp[j as usize];
                j += 1;
            }
            k += 1;
        }

        while i <= mid {
            arr[k as usize] = temp[i as usize];
            i += 1;
            k += 1;
        }
    }

    pub fn new() -> Self {
        Self {
            base: SortBenchmark::new_base(),
        }
    }
}

impl Benchmark for SortMerge {
    fn name(&self) -> String {
        "SortMerge".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("SortMerge");
    }

    fn run(&mut self, _iteration_id: i64) {

        self.base.result_val = self.base.result_val.wrapping_add(
            self.base.data[helper::next_int(self.base.size_val as i32) as usize] as u32
        );
        let mut t = self.base.data.clone();
        Self::merge_sort_inplace(&mut t);
        self.base.result_val = self.base.result_val.wrapping_add(
            t[helper::next_int(self.base.size_val as i32) as usize] as u32
        );
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}