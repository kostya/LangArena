use super::super::{helper, Benchmark};
use crate::config_i64;

struct Cell {
    alive: bool,
    next_state: bool,
    neighbors: Vec<usize>,
}

impl Cell {
    fn new(alive: bool) -> Self {
        Self {
            alive,
            next_state: false,
            neighbors: Vec::with_capacity(8),
        }
    }

    fn add_neighbor(&mut self, cell: usize) {
        self.neighbors.push(cell);
    }

    fn compute_next_state(&self, cells: &[Cell]) -> bool {
        let alive_neighbors = self
            .neighbors
            .iter()
            .filter(|&&idx| cells[idx].alive)
            .count();

        if self.alive {
            alive_neighbors == 2 || alive_neighbors == 3
        } else {
            alive_neighbors == 3
        }
    }

    fn update(&mut self) {
        self.alive = self.next_state;
    }
}

struct Grid {
    width: usize,
    height: usize,
    cells: Vec<Cell>,
}

impl Grid {
    fn new(width: usize, height: usize) -> Self {
        let mut grid = Grid {
            width,
            height,
            cells: (0..width * height).map(|_| Cell::new(false)).collect(),
        };

        grid.link_neighbors();
        grid
    }

    fn link_neighbors(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                let cell = &mut self.cells[y * self.width + x];

                for dy in -1..=1 {
                    for dx in -1..=1 {
                        if dx == 0 && dy == 0 {
                            continue;
                        }

                        let ny =
                            ((y as i32 + dy + self.height as i32) % self.height as i32) as usize;
                        let nx = ((x as i32 + dx + self.width as i32) % self.width as i32) as usize;

                        cell.add_neighbor(ny * self.width + nx);
                    }
                }
            }
        }
    }

    fn next_generation(&mut self) {
        for i in 0..self.cells.len() {
            self.cells[i].next_state = self.cells[i].compute_next_state(&self.cells);
        }
        for cell in &mut self.cells {
            cell.update();
        }
    }

    fn count_alive(&self) -> u32 {
        self.cells.iter().filter(|cell| cell.alive).count() as u32
    }

    fn compute_hash(&self) -> u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;

        self.cells.iter().fold(FNV_OFFSET_BASIS, |hash, cell| {
            let alive = if cell.alive { 1_u32 } else { 0_u32 };
            (hash ^ alive).wrapping_mul(FNV_PRIME)
        })
    }
}

pub struct GameOfLife {
    grid: Grid,
}

impl GameOfLife {
    pub fn new() -> Self {
        let width = config_i64("Etc::GameOfLife", "w") as i32;
        let height = config_i64("Etc::GameOfLife", "h") as i32;
        let grid = Grid::new(width as usize, height as usize);

        Self { grid }
    }
}

impl Benchmark for GameOfLife {
    fn name(&self) -> String {
        "Etc::GameOfLife".to_string()
    }

    fn prepare(&mut self) {
        for y in 0..self.grid.height {
            for x in 0..self.grid.width {
                if helper::next_float(1.0) < 0.1 {
                    self.grid.cells[y * self.grid.width + x].alive = true;
                }
            }
        }
    }

    fn run(&mut self, _iteration_id: i64) {
        self.grid.next_generation();
    }

    fn checksum(&self) -> u32 {
        let alive = self.grid.count_alive();
        self.grid.compute_hash() + alive
    }
}

