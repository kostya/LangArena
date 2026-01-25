use super::super::{helper};

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
        
        // Проверяем границы
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

            // Делаем компоненту связной
            for i in (start_idx + 1)..end_idx {
                let parent = start_idx + helper::next_int((i - start_idx) as i32);
                self.add_edge(i, parent);
            }

            // Добавляем случайные рёбра внутри компоненты
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

// Абстрактный бенчмарк поиска путей в графе
pub struct GraphPathBenchmark {
    pub graph: Graph,
    pub pairs: Vec<(i32, i32)>,
    pub result: i64,
}

impl GraphPathBenchmark {
    pub fn new_base(iterations: i32) -> Self {
        let vertices = iterations * 10;
        let components = std::cmp::max(10, vertices / 10_000);
        let graph = Graph::new(vertices, components);
        
        Self {
            graph,
            pairs: Vec::new(),
            result: 0,
        }
    }
    
    pub fn generate_pairs(&self, n: i32) -> Vec<(i32, i32)> {
        let mut pairs = Vec::with_capacity(n as usize);
        let component_size = self.graph.vertices / 10;
        
        for _ in 0..n {
            // 70% пар в одной компоненте, 30% - в разных
            if helper::next_int(100) < 70 {
                // В одной компоненте
                let component = helper::next_int(10);
                let start = component * component_size + helper::next_int(component_size);
                // end в той же компоненте, но не та же самая вершина
                loop {
                    let end = component * component_size + helper::next_int(component_size);
                    if end != start {
                        pairs.push((start, end));
                        break;
                    }
                }
            } else {
                // В разных компонентах (пути не существует)
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
    
    pub fn prepare_common(&mut self, n_pairs: i32) {
        self.graph.generate_random();
        self.pairs = self.generate_pairs(n_pairs);
    }
}