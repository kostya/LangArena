use super::super::Benchmark;
use crate::benchmarks::graph_path_benchmark::GraphPathBenchmark;
use std::collections::VecDeque;

pub struct GraphPathBFS {
    base: GraphPathBenchmark,
}

impl GraphPathBFS {
    fn bfs_shortest_path(&self, start: i32, target: i32) -> i64 {
        if start == target {
            return 0;
        }

        let vertices = self.base.graph.vertices as usize;
        let mut visited = vec![false; vertices];
        let mut queue = VecDeque::new();

        visited[start as usize] = true;
        queue.push_back((start, 0));

        while let Some((v, dist)) = queue.pop_front() {
            let v_idx = v as usize;

            if v_idx >= self.base.graph.adj.len() {
                continue;
            }

            for &neighbor in &self.base.graph.adj[v_idx] {
                let neighbor_idx = neighbor as usize;

                if neighbor == target {
                    return (dist + 1) as i64;
                }

                if neighbor_idx < vertices && !visited[neighbor_idx] {
                    visited[neighbor_idx] = true;
                    queue.push_back((neighbor, dist + 1));
                }
            }
        }

        -1 
    }

    pub fn new() -> Self {
        Self {
            base: GraphPathBenchmark::new_base(),
        }
    }
}

impl Benchmark for GraphPathBFS {
    fn name(&self) -> String {
        "GraphPathBFS".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathBFS");
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut total_length: i64 = 0;

        for (start, target) in &self.base.pairs {
            total_length += self.bfs_shortest_path(*start, *target);
        }

        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}