use super::super::{Benchmark, INPUT};
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
                    // Нашли путь, запоминаем если он короче
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
        let name = "GraphPathDFS".to_string();
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

impl Benchmark for GraphPathDFS {
    fn name(&self) -> String {
        "GraphPathDFS".to_string()
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
            let length = self.dfs_find_path(start, end);
            total_length += length;
        }
        
        self.base.result = total_length;
    }
    
    fn result(&self) -> i64 {
        self.base.result
    }
}