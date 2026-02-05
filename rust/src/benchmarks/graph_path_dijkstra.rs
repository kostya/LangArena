use super::super::{Benchmark, helper};
use crate::config_i64;
use crate::benchmarks::graph_path_benchmark::GraphPathBenchmark;

pub struct GraphPathDijkstra {
    base: GraphPathBenchmark,
}

impl GraphPathDijkstra {
    const INF: i32 = i32::MAX / 2;

    fn dijkstra_shortest_path(&self, start: i32, target: i32) -> i64 {
        if start == target {
            return 0;
        }

        let mut dist = vec![Self::INF; self.base.graph.vertices as usize];
        let mut visited = vec![0u8; self.base.graph.vertices as usize];

        dist[start as usize] = 0;
        let max_iterations = self.base.graph.vertices as usize;

        for _ in 0..max_iterations {

            let mut u = -1i32;
            let mut min_dist = Self::INF;

            for v in 0..self.base.graph.vertices {
                let v_idx = v as usize;
                if visited[v_idx] == 0 && dist[v_idx] < min_dist {
                    min_dist = dist[v_idx];
                    u = v;
                }
            }

            if u == -1 || min_dist == Self::INF || u == target {
                return if u == target { min_dist as i64 } else { -1 };
            }

            visited[u as usize] = 1;

            for &neighbor in &self.base.graph.adj[u as usize] {
                let neighbor_idx = neighbor as usize;
                let new_dist = dist[u as usize] + 1;
                if new_dist < dist[neighbor_idx] {
                    dist[neighbor_idx] = new_dist;
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

impl Benchmark for GraphPathDijkstra {
    fn name(&self) -> String {
        "GraphPathDijkstra".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathDijkstra");
    }

    fn run(&mut self, _iteration_id: i64) {
        let mut total_length: i64 = 0;

        for (start, target) in &self.base.pairs {
            total_length += self.dijkstra_shortest_path(*start, *target);
        }

        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}