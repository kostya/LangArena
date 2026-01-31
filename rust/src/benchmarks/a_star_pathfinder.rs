use super::super::{Benchmark, helper};
use crate::config_i64;
use super::maze_generator::Maze;
use std::cmp::Ordering;
use std::collections::BinaryHeap as StdBinaryHeap;

// Node с реализацией Ord для max-heap (Rust BinaryHeap по умолчанию max-heap)
#[derive(Debug, Clone, Copy, Eq, PartialEq)]
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

impl Ord for Node {
    fn cmp(&self, other: &Self) -> Ordering {
        // Для max-heap: меньший f_score считается "большим"
        other.f_score.cmp(&self.f_score)
            .then_with(|| self.y.cmp(&other.y))
            .then_with(|| self.x.cmp(&other.x))
    }
}

impl PartialOrd for Node {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

// AStarPathfinder с кэшированием
pub struct AStarPathfinder {
    start_x: i32,
    start_y: i32,
    goal_x: i32,
    goal_y: i32,
    width: i32,
    height: i32,
    maze_grid: Vec<Vec<bool>>,
    result_val: u32,
    
    // Кэшированные массивы (выделяются один раз)
    g_scores_cache: Vec<Vec<i32>>,
    came_from_cache: Vec<Vec<i32>>, // Упакованные координаты: y * width + x
}

impl AStarPathfinder {
    // Inline для производительности
    #[inline]
    fn distance(&self, a_x: i32, a_y: i32, b_x: i32, b_y: i32) -> i32 {
        (a_x - b_x).abs() + (a_y - b_y).abs()
    }
    
    // Упаковка координат
    #[inline]
    fn pack_coords(&self, x: i32, y: i32) -> i32 {
        y * self.width + x
    }
    
    // Распаковка координат
    #[inline]
    fn unpack_coords(&self, packed: i32) -> (i32, i32) {
        (packed % self.width, packed / self.width)
    }
    
    fn find_path_optimized(&mut self) -> (Option<Vec<(i32, i32)>>, i32) {
        let grid = &self.maze_grid;
        let width = self.width as usize;
        let height = self.height as usize;
        
        // Используем кэшированные массивы
        let g_scores = &mut self.g_scores_cache;
        let came_from = &mut self.came_from_cache;
        
        // Быстрая инициализация массивов
        for y in 0..height {
            for x in 0..width {
                g_scores[y][x] = i32::MAX;
                came_from[y][x] = -1;
            }
        }
        
        // Используем стандартный BinaryHeap (max-heap по умолчанию)
        let mut open_set = StdBinaryHeap::with_capacity(width * height);
        let mut nodes_explored = 0;
        
        let start_x_usize = self.start_x as usize;
        let start_y_usize = self.start_y as usize;
        
        g_scores[start_y_usize][start_x_usize] = 0;
        open_set.push(Node::new(
            self.start_x,
            self.start_y,
            self.distance(self.start_x, self.start_y, self.goal_x, self.goal_y)
        ));
        
        // Статический массив направлений (выделяется один раз)
        static DIRECTIONS: [(i32, i32); 4] = [(0, -1), (1, 0), (0, 1), (-1, 0)];
        
        while let Some(current) = open_set.pop() {
            nodes_explored += 1;

            if current.x == self.goal_x && current.y == self.goal_y {
                // Восстанавливаем путь
                let mut path = Vec::with_capacity(width * height);
                let mut x = current.x;
                let mut y = current.y;
                
                while x != self.start_x || y != self.start_y {
                    path.push((x, y));
                    let packed = came_from[y as usize][x as usize];
                    if packed == -1 {
                        break;
                    }
                    let (px, py) = self.unpack_coords(packed);
                    x = px;
                    y = py;
                }
                
                path.push((self.start_x, self.start_y));
                path.reverse();
                return (Some(path), nodes_explored);
            }
            
            let current_g = g_scores[current.y as usize][current.x as usize];
            
            for &(dx, dy) in &DIRECTIONS {
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
                
                let tentative_g = current_g + 1000;
                
                if tentative_g < g_scores[ny_usize][nx_usize] {
                    // Упаковываем координаты
                    came_from[ny_usize][nx_usize] = self.pack_coords(current.x, current.y);
                    g_scores[ny_usize][nx_usize] = tentative_g;
                    
                    let f_score = tentative_g + self.distance(nx, ny, self.goal_x, self.goal_y);
                    open_set.push(Node::new(nx, ny, f_score));
                }
            }
        }
        
        (None, nodes_explored)
    }
    
    pub fn new() -> Self {
        let width = config_i64("AStarPathfinder", "w") as i32;
        let height = config_i64("AStarPathfinder", "h") as i32;
        let start_x = 1;
        let start_y = 1;
        let goal_x = width - 2;
        let goal_y = height - 2;
        
        // Инициализируем кэшированные массивы нулевого размера
        // Они будут перевыделены в prepare()
        Self {
            start_x,
            start_y,
            goal_x,
            goal_y,
            width,
            height,
            maze_grid: Vec::new(),
            result_val: 0,
            g_scores_cache: Vec::new(),
            came_from_cache: Vec::new(),
        }
    }
    
    // Инициализация кэшированных массивов
    fn init_cached_arrays(&mut self) {
        let width = self.width as usize;
        let height = self.height as usize;
        
        if self.g_scores_cache.len() != height || 
           (height > 0 && self.g_scores_cache[0].len() != width) {
            self.g_scores_cache = vec![vec![0; width]; height];
            self.came_from_cache = vec![vec![0; width]; height];
        }
    }
}

impl Benchmark for AStarPathfinder {
    fn name(&self) -> String {
        "AStarPathfinder".to_string()
    }
    
    fn prepare(&mut self) {
        self.maze_grid = Maze::generate_walkable_maze(self.width as usize, self.height as usize);
        self.init_cached_arrays();
    }
    
    fn run(&mut self, _iteration_id: i64) {
        let (path, nodes_explored) = self.find_path_optimized();

        let mut local_result: u32 = 0;
        local_result = local_result.wrapping_shl(5).wrapping_add(
            path.as_ref().map(|p| p.len()).unwrap_or(0) as u32
        );
        local_result = local_result.wrapping_shl(5).wrapping_add(nodes_explored as u32);
        self.result_val = self.result_val.wrapping_add(local_result);
    }
    
    fn checksum(&self) -> u32 {
        self.result_val
    }
}