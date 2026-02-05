use super::super::helper;
use crate::config_i64;

pub struct Graph {
    pub vertices: i32,
    pub adj: Vec<Vec<i32>>,
    components: i32,
}

impl Graph {
    pub fn new(vertices: i32, components: i32) -> Self {
        let mut adj = Vec::with_capacity(vertices as usize);
        for _ in 0..vertices {
            adj.push(Vec::new());
        }

        Self {
            vertices,
            adj,
            components,
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
        let component_size = self.vertices / self.components;

        for c in 0..self.components {
            let start_idx = c * component_size;
            let mut end_idx = (c + 1) * component_size;
            if c == self.components - 1 {
                end_idx = self.vertices;
            }

            for i in (start_idx + 1)..end_idx {
                let parent = start_idx + helper::next_int((i - start_idx) as i32);
                self.add_edge(i, parent);
            }

            for _ in 0..(component_size * 2) {
                let u = start_idx + helper::next_int((end_idx - start_idx) as i32);
                let v = start_idx + helper::next_int((end_idx - start_idx) as i32);
                if u != v {
                    self.add_edge(u, v);
                }
            }
        }
    }
}

pub struct GraphPathBenchmark {
    pub graph: Graph,
    pub pairs: Vec<(i32, i32)>,
    pub result_val: u32,
    pub prepared: bool,
}

impl GraphPathBenchmark {
    pub fn new_base() -> Self {
        Self {
            graph: Graph::new(0, 0), 
            pairs: Vec::new(),
            result_val: 0,
            prepared: false,
        }
    }

    pub fn prepare(&mut self, class_name: &str) {
        if !self.prepared {
            let vertices = config_i64(class_name, "vertices") as i32;
            let comps = std::cmp::max(10, vertices / 10_000);

            let mut graph = Graph::new(vertices, comps);
            graph.generate_random();
            self.graph = graph;

            let n_pairs = config_i64(class_name, "pairs") as i32;
            self.pairs = Self::generate_pairs(&self.graph, n_pairs);

            self.prepared = true;
        }
    }

    fn generate_pairs(graph: &Graph, n: i32) -> Vec<(i32, i32)> {
        let mut pairs = Vec::with_capacity(n as usize);
        let component_size = graph.vertices / 10;

        for _ in 0..n {

            if helper::next_int(100) < 70 {

                let component = helper::next_int(10);
                let start = component * component_size + helper::next_int(component_size);

                loop {
                    let end = component * component_size + helper::next_int(component_size);
                    if end != start {
                        pairs.push((start, end));
                        break;
                    }
                }
            } else {

                let c1 = helper::next_int(10);
                let mut c2 = helper::next_int(10);
                while c2 == c1 {
                    c2 = helper::next_int(10);
                }
                let start = c1 * component_size + helper::next_int(component_size);
                let end = c2 * component_size + helper::next_int(component_size);
                pairs.push((start, end));
            }
        }

        pairs
    }
}