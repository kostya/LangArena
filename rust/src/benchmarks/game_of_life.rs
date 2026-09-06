use super::super::{helper, Benchmark};
use crate::config_i64;

struct Cell {
    alive: bool,
    next_state: bool,
    neighbors: Vec<(usize, usize)>,
}

impl Cell {
    fn new(alive: bool) -> Self {
        Self {
            alive,
            next_state: false,
            neighbors: Vec::with_capacity(8),
        }
    }

    fn add_neighbor(&mut self, x: usize, y: usize) {
        self.neighbors.push((x, y));
    }

    fn compute_next_state(&self, cells: &[Vec<Cell>]) -> bool {
        let alive_neighbors = self
            .neighbors
            .iter()
            .filter(|&&(x, y)| cells[y][x].alive)
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
    cells: Vec<Vec<Cell>>,
}

impl Grid {
    fn new(width: usize, height: usize) -> Self {
        let mut grid = Grid {
            width,
            height,
            cells: (0..height)
                .map(|_| (0..width).map(|_| Cell::new(false)).collect())
                .collect(),
        };

        grid.link_neighbors();
        grid
    }

    fn link_neighbors(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                for dy in -1..=1_i32 {
                    for dx in -1..=1_i32 {
                        if dx == 0 && dy == 0 {
                            continue;
                        }

                        let ny =
                            ((y as i32 + dy + self.height as i32) % self.height as i32) as usize;
                        let nx = ((x as i32 + dx + self.width as i32) % self.width as i32) as usize;

                        self.cells[y][x].add_neighbor(nx, ny);
                    }
                }
            }
        }
    }

    fn next_generation(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                let next_state = self.cells[y][x].compute_next_state(&self.cells);
                self.cells[y][x].next_state = next_state;
            }
        }

        for row in &mut self.cells {
            for cell in row {
                cell.update();
            }
        }
    }

    fn count_alive(&self) -> u32 {
        self.cells
            .iter()
            .flat_map(|row| row.iter())
            .filter(|cell| cell.alive)
            .count() as u32
    }

    fn compute_hash(&self) -> u32 {
        const FNV_OFFSET_BASIS: u32 = 2166136261;
        const FNV_PRIME: u32 = 16777619;

        self.cells
            .iter()
            .flat_map(|row| row.iter())
            .fold(FNV_OFFSET_BASIS, |hash, cell| {
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
                    self.grid.cells[y][x].alive = true;
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
