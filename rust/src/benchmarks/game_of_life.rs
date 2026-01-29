use super::super::{Benchmark, helper};
use crate::config_i64;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Cell {
    Dead,
    Alive,
}

impl Cell {
    #[inline]
    fn is_alive(&self) -> bool {
        matches!(self, Cell::Alive)
    }
}

#[derive(Debug, Clone)]
pub struct Grid {
    width: usize,
    height: usize,
    cells: Vec<Vec<Cell>>,
}

impl Grid {
    pub fn new(width: usize, height: usize) -> Self {
        let cells = vec![vec![Cell::Dead; width]; height];
        Self { width, height, cells }
    }
    
    #[inline]
    pub fn get(&self, x: usize, y: usize) -> Cell {
        self.cells[y][x]
    }
    
    #[inline]
    pub fn set(&mut self, x: usize, y: usize, cell: Cell) {
        self.cells[y][x] = cell;
    }
    
    pub fn count_neighbors(&self, x: usize, y: usize) -> usize {
        let mut count = 0;
        
        for dy in -1..=1 {
            for dx in -1..=1 {
                if dx == 0 && dy == 0 {
                    continue;
                }
                
                let nx = (x as isize + dx).rem_euclid(self.width as isize) as usize;
                let ny = (y as isize + dy).rem_euclid(self.height as isize) as usize;
                
                if self.cells[ny][nx].is_alive() {
                    count += 1;
                }
            }
        }
        
        count
    }
    
    pub fn next_generation(&self) -> Self {
        let mut next = Grid::new(self.width, self.height);
        
        for y in 0..self.height {
            for x in 0..self.width {
                let neighbors = self.count_neighbors(x, y);
                let current = self.cells[y][x];
                
                let next_state = match (current, neighbors) {
                    (Cell::Alive, 2) | (Cell::Alive, 3) => Cell::Alive,
                    (Cell::Alive, _) => Cell::Dead,
                    (Cell::Dead, 3) => Cell::Alive,
                    (Cell::Dead, _) => Cell::Dead,
                };
                
                next.cells[y][x] = next_state;
            }
        }
        
        next
    }
    
    pub fn compute_hash(&self) -> u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;
        
        let mut hasher = FNV_OFFSET_BASIS;
        
        for row in &self.cells {
            for cell in row {
                let alive = if cell.is_alive() { 1 } else { 0 };
                // ВАЖНО: сначала XOR, потом умножение, как в C++ версии
                hasher = hasher ^ alive;
                hasher = hasher.wrapping_mul(FNV_PRIME);
            }
        }
        
        hasher
    }
}

pub struct GameOfLife {
    width_: i32,
    height_: i32,
    grid_: Grid,
    result_val: u32,
}

impl GameOfLife {
    pub fn new() -> Self {
        let width_ = config_i64("GameOfLife", "w") as i32;
        let height_ = config_i64("GameOfLife", "h") as i32;
        let grid_ = Grid::new(width_ as usize, height_ as usize);
        
        Self {
            width_,
            height_,
            grid_,
            result_val: 0,
        }
    }
}

impl Benchmark for GameOfLife {
    fn name(&self) -> String {
        "GameOfLife".to_string()
    }
    
    fn prepare(&mut self) {
        // Инициализация случайными клетками
        for y in 0..self.height_ as usize {
            for x in 0..self.width_ as usize {
                if helper::next_float(1.0) < 0.1 {
                    self.grid_.set(x, y, Cell::Alive);
                }
            }
        }
    }
    
    fn run(&mut self, _iteration_id: i64) {
        self.grid_ = self.grid_.next_generation();
    }
    
    fn checksum(&self) -> u32 {
        self.grid_.compute_hash()
    }
}