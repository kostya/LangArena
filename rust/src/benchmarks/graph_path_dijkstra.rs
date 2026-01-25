use super::super::{Benchmark, INPUT};
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
            // Находим непосещённую вершину с минимальным расстоянием
            let mut u = -1i32;
            let mut min_dist = Self::INF;

            for v in 0..self.base.graph.vertices {
                let v_idx = v as usize;
                if visited[v_idx] == 0 && dist[v_idx] < min_dist {
                    min_dist = dist[v_idx];
                    u = v;
                }
            }

            // Выход если нет вершин или нашли цель
            if u == -1 || min_dist == Self::INF || u == target {
                return if u == target { min_dist as i64 } else { -1 };
            }

            visited[u as usize] = 1;

            // Обновляем расстояния до соседей
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
        let name = "GraphPathDijkstra".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        Self {
            base: GraphPathBenchmark::new_base(iterations),
        }
    }
}

impl Benchmark for GraphPathDijkstra {
    fn name(&self) -> String {
        "GraphPathDijkstra".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.base.pairs.len() as i32
    }
    
    fn prepare(&mut self) {
        let n_pairs = self.base.pairs.len() as i32;
        if n_pairs == 0 {
            let iterations = INPUT.get()
                .unwrap()
                .get(&self.name())
                .and_then(|s| s.parse().ok())
                .unwrap_or(0);
            self.base.prepare_common(iterations);
        }
    }
    
    fn run(&mut self) {
        let mut total_length = 0i64;
        
        for &(start, end) in &self.base.pairs {
            let length = self.dijkstra_shortest_path(start, end);
            total_length += length;
        }
        
        self.base.result = total_length;
    }
    
    fn result(&self) -> i64 {
        self.base.result
    }
}