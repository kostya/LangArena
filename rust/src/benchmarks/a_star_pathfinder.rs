use super::super::{Benchmark, INPUT, helper};
use super::maze_generator::Maze;
use std::cmp::Ordering;

// Heuristics
trait Heuristic: Send + Sync {
    fn distance(&self, a: (usize, usize), b: (usize, usize)) -> i32;
}

struct ManhattanHeuristic;
struct EuclideanHeuristic;
struct ChebyshevHeuristic;

impl Heuristic for ManhattanHeuristic {
    fn distance(&self, (x1, y1): (usize, usize), (x2, y2): (usize, usize)) -> i32 {
        ((x1 as i32 - x2 as i32).abs() + (y1 as i32 - y2 as i32).abs()) * 1000
    }
}

impl Heuristic for EuclideanHeuristic {
    fn distance(&self, (x1, y1): (usize, usize), (x2, y2): (usize, usize)) -> i32 {
        let dx = (x1 as f64 - x2 as f64).abs();
        let dy = (y1 as f64 - y2 as f64).abs();
        (dx.hypot(dy) * 1000.0) as i32
    }
}

impl Heuristic for ChebyshevHeuristic {
    fn distance(&self, (x1, y1): (usize, usize), (x2, y2): (usize, usize)) -> i32 {
        (x1.abs_diff(x2).max(y1.abs_diff(y2)) as i32) * 1000
    }
}

// BinaryHeap (минимальная куча)
struct BinaryHeap<T> {
    data: Vec<T>,
}

impl<T: Ord> BinaryHeap<T> {
    fn new() -> Self {
        BinaryHeap { data: Vec::new() }
    }
    
    fn push(&mut self, item: T) {
        self.data.push(item);
        self.sift_up(self.data.len() - 1);
    }
    
    fn pop(&mut self) -> Option<T> {
        if self.data.len() <= 1 {
            return self.data.pop();
        }
        
        let result = self.data.swap_remove(0);
        self.sift_down(0);
        Some(result)
    }
    
    fn is_empty(&self) -> bool {
        self.data.is_empty()
    }
    
    fn sift_up(&mut self, mut index: usize) {
        while index > 0 {
            let parent = (index - 1) / 2;
            if self.data[index] >= self.data[parent] {
                break;
            }
            self.data.swap(index, parent);
            index = parent;
        }
    }
    
    fn sift_down(&mut self, mut index: usize) {
        let len = self.data.len();
        loop {
            let left = index * 2 + 1;
            let right = left + 1;
            let mut smallest = index;
            
            if left < len && self.data[left] < self.data[smallest] {
                smallest = left;
            }
            
            if right < len && self.data[right] < self.data[smallest] {
                smallest = right;
            }
            
            if smallest == index {
                break;
            }
            
            self.data.swap(index, smallest);
            index = smallest;
        }
    }
}

// Node
#[derive(Debug, Clone, Copy, Eq)]
struct Node {
    x: i32,
    y: i32,
    f_score: i32,
}

impl Node {
    fn new(x: i32, y: i32, f_score: i32) -> Self {
        Node { x, y, f_score }
    }
}

impl PartialEq for Node {
    fn eq(&self, other: &Self) -> bool {
        self.f_score == other.f_score && self.x == other.x && self.y == other.y
    }
}

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        self.f_score.cmp(&other.f_score)
            .then_with(|| self.x.cmp(&other.x))
            .then_with(|| self.y.cmp(&other.y))
    }
}

impl PartialOrd for Node {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

// AStarPathfinder
pub struct AStarPathfinder {
    iterations: i32,
    result: i64,
    maze_grid: Option<Vec<Vec<bool>>>,
    start: (i32, i32),
    goal: (i32, i32),
    width: i32,
    height: i32,
}

impl AStarPathfinder {
    pub fn new() -> Self {
        let name = "AStarPathfinder".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(5);
        
        let width = iterations;
        let height = iterations;
        let start = (1, 1);
        let goal = (width - 2, height - 2);
        
        Self {
            iterations,
            result: 0,
            maze_grid: None,
            start,
            goal,
            width,
            height,
        }
    }
    
    fn ensure_maze_grid(&mut self) -> &Vec<Vec<bool>> {
        if self.maze_grid.is_none() {
            let maze_grid = Maze::generate_walkable_maze(
                self.width as usize, 
                self.height as usize
            );
            self.maze_grid = Some(maze_grid);
        }
        self.maze_grid.as_ref().unwrap()
    }
        
    fn find_path(&self, heuristic: &dyn Heuristic, allow_diagonal: bool) -> Option<Vec<(i32, i32)>> {
        let grid = self.maze_grid.as_ref().unwrap();
        
        let width = self.width as usize;
        let height = self.height as usize;
        
        let mut g_scores = vec![vec![i32::MAX; width]; height];
        let mut came_from = vec![vec![(-1, -1); width]; height];
        let mut open_set = BinaryHeap::new();
        
        g_scores[self.start.1 as usize][self.start.0 as usize] = 0;
        open_set.push(Node::new(
            self.start.0,
            self.start.1,
            heuristic.distance(
                (self.start.0 as usize, self.start.1 as usize),
                (self.goal.0 as usize, self.goal.1 as usize)
            )
        ));
        
        let directions = if allow_diagonal {
            vec![
                (0, -1), (1, 0), (0, 1), (-1, 0),
                (-1, -1), (1, -1), (1, 1), (-1, 1),
            ]
        } else {
            vec![(0, -1), (1, 0), (0, 1), (-1, 0)]
        };
        
        let diagonal_cost = if allow_diagonal { 1414 } else { 1000 };
        
        while let Some(current) = open_set.pop() {
            if current.x == self.goal.0 && current.y == self.goal.1 {
                let mut path = Vec::new();
                let mut x = current.x;
                let mut y = current.y;
                
                while x != self.start.0 || y != self.start.1 {
                    path.push((x, y));
                    let (px, py) = came_from[y as usize][x as usize];
                    x = px;
                    y = py;
                }
                
                path.push((self.start.0, self.start.1));
                path.reverse();
                return Some(path);
            }
            
            let current_g = g_scores[current.y as usize][current.x as usize];
            
            for (dx, dy) in &directions {
                let nx = current.x + dx;
                let ny = current.y + dy;
                
                if nx < 0 || ny < 0 || nx >= self.width || ny >= self.height {
                    continue;
                }
                
                let nx_usize = nx as usize;
                let ny_usize = ny as usize;
                
                if !grid[ny_usize][nx_usize] {
                    continue;
                }
                
                let move_cost = if dx.abs() == 1 && dy.abs() == 1 {
                    diagonal_cost
                } else {
                    1000
                };
                
                let tentative_g = current_g + move_cost;
                
                if tentative_g < g_scores[ny_usize][nx_usize] {
                    came_from[ny_usize][nx_usize] = (current.x, current.y);
                    g_scores[ny_usize][nx_usize] = tentative_g;
                    
                    let f_score = tentative_g + heuristic.distance(
                        (nx_usize, ny_usize),
                        (self.goal.0 as usize, self.goal.1 as usize)
                    );
                    
                    open_set.push(Node::new(nx, ny, f_score));
                }
            }
        }
        
        None
    }
    
    fn estimate_nodes_explored(&self, heuristic: &dyn Heuristic, allow_diagonal: bool) -> i32 {
        let grid = self.maze_grid.as_ref().unwrap();
        
        let width = self.width as usize;
        let height = self.height as usize;
        
        let mut g_scores = vec![vec![i32::MAX; width]; height];
        let mut open_set = BinaryHeap::new();
        let mut closed = vec![vec![false; width]; height];
        
        g_scores[self.start.1 as usize][self.start.0 as usize] = 0;
        open_set.push(Node::new(
            self.start.0,
            self.start.1,
            heuristic.distance(
                (self.start.0 as usize, self.start.1 as usize),
                (self.goal.0 as usize, self.goal.1 as usize)
            )
        ));
        
        let directions = if allow_diagonal {
            vec![
                (0, -1), (1, 0), (0, 1), (-1, 0),
                (-1, -1), (1, -1), (1, 1), (-1, 1),
            ]
        } else {
            vec![(0, -1), (1, 0), (0, 1), (-1, 0)]
        };
        
        let mut nodes_explored = 0;
        
        while let Some(current) = open_set.pop() {
            if current.x == self.goal.0 && current.y == self.goal.1 {
                break;
            }
            
            if closed[current.y as usize][current.x as usize] {
                continue;
            }
            
            closed[current.y as usize][current.x as usize] = true;
            nodes_explored += 1;
            
            let current_g = g_scores[current.y as usize][current.x as usize];
            
            for (dx, dy) in &directions {
                let nx = current.x + dx;
                let ny = current.y + dy;
                
                if nx < 0 || ny < 0 || nx >= self.width || ny >= self.height {
                    continue;
                }
                
                let nx_usize = nx as usize;
                let ny_usize = ny as usize;
                
                if !grid[ny_usize][nx_usize] {
                    continue;
                }
                
                let move_cost = if dx.abs() == 1 && dy.abs() == 1 { 1414 } else { 1000 };
                let tentative_g = current_g + move_cost;
                
                if tentative_g < g_scores[ny_usize][nx_usize] {
                    g_scores[ny_usize][nx_usize] = tentative_g;
                    
                    let f_score = tentative_g + heuristic.distance(
                        (nx_usize, ny_usize),
                        (self.goal.0 as usize, self.goal.1 as usize)
                    );
                    
                    open_set.push(Node::new(nx, ny, f_score));
                }
            }
        }
        
        nodes_explored
    }
    
    fn benchmark_different_approaches(&self) -> (i32, i32, i32) {
        let manhattan = ManhattanHeuristic;
        let euclidean = EuclideanHeuristic;
        let chebyshev = ChebyshevHeuristic;
        
        let heuristics: Vec<&dyn Heuristic> = vec![
            &manhattan,
            &euclidean,
            &chebyshev,
        ];
        
        let mut total_paths_found = 0;
        let mut total_path_length = 0;
        let mut total_nodes_explored = 0;
        
        for heuristic in heuristics {
            if let Some(path) = self.find_path(heuristic, false) {
                total_paths_found += 1;
                total_path_length += path.len() as i32;
                
                let nodes_explored = self.estimate_nodes_explored(heuristic, false);
                total_nodes_explored += nodes_explored;
            }
        }
        
        (total_paths_found, total_path_length, total_nodes_explored)
    }
}

impl Benchmark for AStarPathfinder {
    fn name(&self) -> String {
        "AStarPathfinder".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.iterations
    }

    fn prepare(&mut self) {
        self.ensure_maze_grid();
    }
    
    fn run(&mut self) {
        let mut total_paths_found = 0;
        let mut total_path_length = 0;
        let mut total_nodes_explored = 0;
        
        let iters = 10;
        for _ in 0..iters {
            let (paths_found, path_length, nodes_explored) = self.benchmark_different_approaches();
            
            total_paths_found += paths_found;
            total_path_length += path_length;
            total_nodes_explored += nodes_explored;
        }
        
        let paths_checksum = helper::checksum_f64(total_paths_found as f64);
        let length_checksum = helper::checksum_f64(total_path_length as f64);
        let nodes_checksum = helper::checksum_f64(total_nodes_explored as f64);

        self.result = (paths_checksum as i64) ^ 
                     ((length_checksum as i64) << 16) ^ 
                     ((nodes_checksum as i64) << 32);
    }
    
    fn result(&self) -> i64 {
        self.result
    }
}