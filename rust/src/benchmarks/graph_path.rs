use super::super::helper;
use crate::config_i64;
use std::collections::VecDeque;
use std::cmp;

pub struct Graph {
    pub vertices: i32,
    pub jumps: i32,
    pub jump_len: i32,
    pub adj: Vec<Vec<i32>>,
}

impl Graph {
    pub fn new(vertices: i32, jumps: i32, jump_len: i32) -> Self {
        let mut adj = Vec::with_capacity(vertices as usize);
        for _ in 0..vertices {
            adj.push(Vec::new());
        }

        Self {
            vertices,
            jumps,
            jump_len,
            adj,
        }
    }

    pub fn add_edge(&mut self, u: i32, v: i32) {
        let u_idx = u as usize;
        let v_idx = v as usize;

        if u_idx < self.adj.len() && v_idx < self.adj.len() {
            self.adj[u_idx].push(v);
            self.adj[v_idx].push(u);
        }
    }

    pub fn generate_random(&mut self) {

        for i in 1..self.vertices {
            self.add_edge(i, i - 1);
        }

        for v in 0..self.vertices {
            let num_jumps = helper::next_int(self.jumps as i32) as i32;
            for _ in 0..num_jumps {
                let offset = helper::next_int(self.jump_len as i32) - self.jump_len / 2;
                let u = v + offset;

                if u >= 0 && u < self.vertices && u != v {
                    self.add_edge(v, u);
                }
            }
        }
    }
}

pub struct GraphPathBenchmark {
    pub graph: Graph,
    pub result_val: u32,
    pub prepared: bool,
}

impl GraphPathBenchmark {
    pub fn new_base() -> Self {
        Self {
            graph: Graph::new(0, 0, 0),
            result_val: 0,
            prepared: false,
        }
    }

    pub fn prepare(&mut self, class_name: &str) {
        if !self.prepared {
            let vertices = config_i64(class_name, "vertices") as i32;
            let jumps = config_i64(class_name, "jumps") as i32;
            let jump_len = config_i64(class_name, "jump_len") as i32;

            let mut graph = Graph::new(vertices, jumps, jump_len);
            graph.generate_random();
            self.graph = graph;

            self.prepared = true;
        }
    }
}

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

            for &neighbor in &self.base.graph.adj[v_idx] {
                if neighbor == target {
                    return (dist + 1) as i64;
                }

                let neighbor_idx = neighbor as usize;
                if !visited[neighbor_idx] {
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

impl super::super::Benchmark for GraphPathBFS {
    fn name(&self) -> String {
        "GraphPathBFS".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathBFS");
    }

    fn run(&mut self, _iteration_id: i64) {
        let total_length = self.bfs_shortest_path(0, self.base.graph.vertices - 1);
        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}

pub struct GraphPathDFS {
    base: GraphPathBenchmark,
}

impl GraphPathDFS {
    fn dfs_find_path(&self, start: i32, target: i32) -> i64 {
        if start == target {
            return 0;
        }

        let vertices = self.base.graph.vertices as usize;
        let mut visited = vec![false; vertices];
        let mut stack = vec![(start, 0)];
        let mut best_path = i32::MAX;

        while let Some((v, dist)) = stack.pop() {
            if visited[v as usize] || dist >= best_path {
                continue;
            }
            visited[v as usize] = true;

            for &neighbor in &self.base.graph.adj[v as usize] {
                if neighbor == target {
                    if dist + 1 < best_path {
                        best_path = dist + 1;
                    }
                } else if !visited[neighbor as usize] {
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

impl super::super::Benchmark for GraphPathDFS {
    fn name(&self) -> String {
        "GraphPathDFS".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathDFS");
    }

    fn run(&mut self, _iteration_id: i64) {
        let total_length = self.dfs_find_path(0, self.base.graph.vertices - 1);
        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}

use std::cmp::Ordering;
use std::collections::BinaryHeap;

#[derive(Copy, Clone, Eq, PartialEq)]
struct Node {
    vertex: i32,
    f_score: i32,
}

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        other.f_score.cmp(&self.f_score)
    }
}

impl PartialOrd for Node {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

pub struct GraphPathAStar {
    base: GraphPathBenchmark,
}

impl GraphPathAStar {
    fn heuristic(&self, v: i32, target: i32) -> i32 {
        target - v
    }

    fn a_star_shortest_path(&self, start: i32, target: i32) -> i64 {
        if start == target {
            return 0;
        }

        let vertices = self.base.graph.vertices as usize;
        let mut g_score = vec![i32::MAX; vertices];
        let mut closed = vec![false; vertices];

        g_score[start as usize] = 0;

        let mut open_set = BinaryHeap::new();
        let mut in_open_set = vec![false; vertices];

        open_set.push(Node {
            vertex: start,
            f_score: self.heuristic(start, target),
        });
        in_open_set[start as usize] = true;

        while let Some(current) = open_set.pop() {
            in_open_set[current.vertex as usize] = false;

            if current.vertex == target {
                return g_score[current.vertex as usize] as i64;
            }

            closed[current.vertex as usize] = true;

            for &neighbor in &self.base.graph.adj[current.vertex as usize] {
                if closed[neighbor as usize] {
                    continue;
                }

                let tentative_g = g_score[current.vertex as usize] + 1;

                if tentative_g < g_score[neighbor as usize] {
                    g_score[neighbor as usize] = tentative_g;
                    let f = tentative_g + self.heuristic(neighbor, target);

                    if !in_open_set[neighbor as usize] {
                        open_set.push(Node {
                            vertex: neighbor,
                            f_score: f,
                        });
                        in_open_set[neighbor as usize] = true;
                    }
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

impl super::super::Benchmark for GraphPathAStar {
    fn name(&self) -> String {
        "GraphPathAStar".to_string()
    }

    fn prepare(&mut self) {
        self.base.prepare("GraphPathAStar");
    }

    fn run(&mut self, _iteration_id: i64) {
        let total_length = self.a_star_shortest_path(0, self.base.graph.vertices - 1);
        self.base.result_val = self.base.result_val.wrapping_add(total_length as u32);
    }

    fn checksum(&self) -> u32 {
        self.base.result_val
    }
}