use super::super::{Benchmark, helper};
use crate::config_i64;
use super::maze_generator::Maze;
use std::cmp::Ordering;

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
    start_x_: i32,
    start_y_: i32,
    goal_x_: i32,
    goal_y_: i32,
    width_: i32,
    height_: i32,
    maze_grid: Vec<Vec<bool>>,
    result_val: u32,
}

impl AStarPathfinder {
    fn distance(&self, a_x: i32, a_y: i32, b_x: i32, b_y: i32) -> i32 {
        ((a_x - b_x).abs() + (a_y - b_y).abs()) as i32
    }
    
    fn find_path(&self) -> (Option<Vec<(i32, i32)>>, i32) {
        let grid = &self.maze_grid;
        
        let width = self.width_ as usize;
        let height = self.height_ as usize;
        
        let mut g_scores = vec![vec![i32::MAX; width]; height];
        let mut came_from = vec![vec![(-1, -1); width]; height];
        let mut open_set = BinaryHeap::new();
        let mut nodes_explored = 0;
        
        g_scores[self.start_y_ as usize][self.start_x_ as usize] = 0;
        open_set.push(Node::new(
            self.start_x_,
            self.start_y_,
            self.distance(self.start_x_, self.start_y_, self.goal_x_, self.goal_y_)
        ));
        
        let directions = vec![(0, -1), (1, 0), (0, 1), (-1, 0)];
        
        while let Some(current) = open_set.pop() {
            nodes_explored += 1;

            if current.x == self.goal_x_ && current.y == self.goal_y_ {
                let mut path = Vec::new();
                let mut x = current.x;
                let mut y = current.y;
                
                while x != self.start_x_ || y != self.start_y_ {
                    path.push((x, y));
                    let (px, py) = came_from[y as usize][x as usize];
                    x = px;
                    y = py;
                }
                
                path.push((self.start_x_, self.start_y_));
                path.reverse();
                return (Some(path), nodes_explored);
            }
            
            let current_g = g_scores[current.y as usize][current.x as usize];
            
            for (dx, dy) in &directions {
                let nx = current.x + dx;
                let ny = current.y + dy;
                
                if nx < 0 || ny < 0 || nx >= self.width_ || ny >= self.height_ {
                    continue;
                }
                
                let nx_usize = nx as usize;
                let ny_usize = ny as usize;
                
                if !grid[ny_usize][nx_usize] {
                    continue;
                }
                
                let tentative_g = current_g + 1000;
                
                if tentative_g < g_scores[ny_usize][nx_usize] {
                    came_from[ny_usize][nx_usize] = (current.x, current.y);
                    g_scores[ny_usize][nx_usize] = tentative_g;
                    
                    let f_score = tentative_g + self.distance(nx, ny, self.goal_x_, self.goal_y_);
                    
                    open_set.push(Node::new(nx, ny, f_score));
                }
            }
        }
        
        (None, nodes_explored)
    }
    
    pub fn new() -> Self {
        let width_ = config_i64("AStarPathfinder", "w") as i32;
        let height_ = config_i64("AStarPathfinder", "h") as i32;
        let start_x_ = 1;
        let start_y_ = 1;
        let goal_x_ = width_ - 2;
        let goal_y_ = height_ - 2;
        
        Self {
            start_x_,
            start_y_,
            goal_x_,
            goal_y_,
            width_,
            height_,
            maze_grid: Vec::new(),
            result_val: 0,
        }
    }
}

impl Benchmark for AStarPathfinder {
    fn name(&self) -> String {
        "AStarPathfinder".to_string()
    }
    
    fn prepare(&mut self) {
        self.maze_grid = Maze::generate_walkable_maze(self.width_ as usize, self.height_ as usize);
    }
    
    fn run(&mut self, _iteration_id: i64) {
        let (path, nodes_explored) = self.find_path();

        let mut local_result: u32 = 0;
        local_result = (local_result << 5) + (path.map(|p| p.len()).unwrap_or(0) as u32);
        local_result = (local_result << 5) + nodes_explored as u32;
        self.result_val = self.result_val.wrapping_add(local_result);
    }
    
    fn checksum(&self) -> u32 {
        self.result_val
    }
}