use super::super::{Benchmark, helper};
use crate::config_i64;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Cell {
    Dead = 0,
    Alive = 1,
}

impl Cell {
    #[inline]
    fn is_alive(&self) -> bool {
        *self as u8 == 1
    }
}

#[derive(Clone)]
pub struct Grid {
    width: usize,
    height: usize,
    cells: Vec<u8>,           
    buffer: Vec<u8>,          
}

impl Grid {
    pub fn new(width: usize, height: usize) -> Self {
        let size = width * height;
        Self {
            width,
            height,
            cells: vec![0; size],
            buffer: vec![0; size],
        }
    }

    fn with_buffers(width: usize, height: usize, cells: Vec<u8>, buffer: Vec<u8>) -> Self {
        Self {
            width,
            height,
            cells,
            buffer,
        }
    }

    #[inline]
    fn index(&self, x: usize, y: usize) -> usize {
        y * self.width + x
    }

    #[inline]
    pub fn get(&self, x: usize, y: usize) -> Cell {
        let idx = self.index(x, y);
        if self.cells[idx] == 1 {
            Cell::Alive
        } else {
            Cell::Dead
        }
    }

    #[inline]
    pub fn set(&mut self, x: usize, y: usize, cell: Cell) {
        let idx = self.index(x, y);
        self.cells[idx] = cell as u8;
    }

    #[inline]
    fn count_neighbors(&self, x: usize, y: usize, cells: &[u8]) -> usize {
        let width = self.width;
        let height = self.height;

        let y_prev = if y == 0 { height - 1 } else { y - 1 };
        let y_next = if y == height - 1 { 0 } else { y + 1 };
        let x_prev = if x == 0 { width - 1 } else { x - 1 };
        let x_next = if x == width - 1 { 0 } else { x + 1 };

        let mut count = 0;

        let mut idx = y_prev * width;
        if cells[idx + x_prev] == 1 { count += 1; }
        if cells[idx + x] == 1 { count += 1; }
        if cells[idx + x_next] == 1 { count += 1; }

        idx = y * width;
        if cells[idx + x_prev] == 1 { count += 1; }
        if cells[idx + x_next] == 1 { count += 1; }

        idx = y_next * width;
        if cells[idx + x_prev] == 1 { count += 1; }
        if cells[idx + x] == 1 { count += 1; }
        if cells[idx + x_next] == 1 { count += 1; }

        count
    }

    pub fn next_generation(&self) -> Self {
        let width = self.width;
        let height = self.height;

        let cells = &self.cells;

        let mut new_buffer = self.buffer.clone();

        for y in 0..height {
            let y_idx = y * width;

            for x in 0..width {
                let idx = y_idx + x;

                let neighbors = self.count_neighbors(x, y, cells);

                let current = cells[idx];
                let next_state = match (current, neighbors) {
                    (1, 2) | (1, 3) => 1,
                    (1, _) => 0,
                    (0, 3) => 1,
                    _ => 0,
                };

                new_buffer[idx] = next_state;
            }
        }

        Self::with_buffers(width, height, new_buffer, cells.clone())
    }

    pub fn compute_hash(&self) -> u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;

        let mut hasher = FNV_OFFSET_BASIS;

        for &cell in &self.cells {
            let alive = cell as u32;

            hasher ^= alive;
            hasher = hasher.wrapping_mul(FNV_PRIME);
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