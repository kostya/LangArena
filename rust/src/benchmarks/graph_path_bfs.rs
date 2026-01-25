use super::super::{Benchmark, INPUT};
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
            
            // Проверяем границы
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

        -1 // путь не найден
    }
    
    pub fn new() -> Self {
        let name = "GraphPathBFS".to_string();
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

impl Benchmark for GraphPathBFS {
    fn name(&self) -> String {
        "GraphPathBFS".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.base.pairs.len() as i32
    }
    
    fn prepare(&mut self) {
        let name = self.name();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(0);
        
        // Важно: используем тот же размер графа, что в оригинале
        self.base.prepare_common(iterations);
    }
    
    fn run(&mut self) {
        let mut total_length = 0i64;
        
        for &(start, end) in &self.base.pairs {
            let length = self.bfs_shortest_path(start, end);
            total_length += length;
        }
        
        self.base.result = total_length;
    }
    
    fn result(&self) -> i64 {
        self.base.result
    }
}