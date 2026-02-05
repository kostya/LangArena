use super::super::{Benchmark, helper};
use crate::config_i64;
use crate::benchmarks::graph_path_benchmark::GraphPathBenchmark;

pub struct GraphPathDFS {
    base: GraphPathBenchmark,
}

impl GraphPathDFS {
    fn dfs_find_path(&self, start: i32, target: i32) -> i64 {
        if start == target {
            return 0;
        }

        let mut visited = vec![0u8; self.base.graph.vertices as usize];
        let mut stack = vec![(start, 0)];
        let mut best_path = i32::MAX;

        while let Some((v, dist)) = stack.pop() {
            if visited[v as usize] == 1 || dist >= best_path {
                continue;
            }
            visited[v as usize] = 1;

            for &neighbor in &self.base.graph.adj[v as usize] {
                if neighbor == target {

                    if dist + 1 < best_path {
                        best_path = dist + 1;
                    }
                } else if visited[neighbor as usize] == 0 {
                    stack.push((neighbor, dist + 1));
                }
            }
        }

        if best_path == i32::MAX {
            -1
        } else {
            best_path as i64
        }
    }

    pub fn new() -> Self {
        Self {
            base: GraphPathBenchmark::new_base(),
        }
    }
}

impl Benchmark for GraphPathDFS {
    fn name(&self) -> String {
        "GraphPathDFS".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathDFS");
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut total_length: i64 = 0;

        for (start, target) in &self.base.pairs {
            total_length += self.dfs_find_path(*start, *target);
        }

        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}