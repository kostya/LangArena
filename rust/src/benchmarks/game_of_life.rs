use super::super::{Benchmark, INPUT, helper};
use std::hash::{Hash, Hasher};

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
    
    #[inline]
    fn from_bool(alive: bool) -> Self {
        if alive { Cell::Alive } else { Cell::Dead }
    }
}

// ПРЯМАЯ РЕАЛИЗАЦИЯ с Vec<Vec<Cell>>
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
    
    // Прямой доступ - Rust сам делает bounds checking
    #[inline]
    pub fn get(&self, x: usize, y: usize) -> Cell {
        self.cells[y][x]
    }
    
    #[inline]
    pub fn get_mut(&mut self, x: usize, y: usize) -> &mut Cell {
        &mut self.cells[y][x]
    }
    
    #[inline]
    pub fn set(&mut self, x: usize, y: usize, cell: Cell) {
        self.cells[y][x] = cell;
    }
    
    // Подсчет соседей с ТОРОИДАЛЬНОЙ ГЕОМЕТРИЕЙ
    pub fn count_neighbors(&self, x: usize, y: usize) -> usize {
        let mut count = 0;
        
        // ИДИОМАТИЧЕСКИЙ ОБХОД соседей
        for dy in -1..=1 {
            for dx in -1..=1 {
                if dx == 0 && dy == 0 {
                    continue; // Пропускаем саму клетку
                }
                
                // Тороидальные координаты
                let nx = (x as isize + dx).rem_euclid(self.width as isize) as usize;
                let ny = (y as isize + dy).rem_euclid(self.height as isize) as usize;
                
                if self.cells[ny][nx].is_alive() {
                    count += 1;
                }
            }
        }
        
        count
    }
    
    // ШАГ СИМУЛЯЦИИ с двойной буферизацией
    pub fn next_generation(&self) -> Self {
        let mut next = Grid::new(self.width, self.height);
        
        // Прямой обход всех клеток
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
    
    // Инициализация паттернами
    pub fn with_pattern(mut self, pattern: &[&str]) -> Self {
        let start_y = self.height / 2 - pattern.len() / 2;
        let start_x = self.width / 2 - pattern[0].len() / 2;
        
        for (dy, line) in pattern.iter().enumerate() {
            for (dx, ch) in line.chars().enumerate() {
                let x = start_x + dx;
                let y = start_y + dy;
                
                if x < self.width && y < self.height {
                    let cell = match ch {
                        'O' | 'X' | '*' => Cell::Alive,
                        _ => Cell::Dead,
                    };
                    self.cells[y][x] = cell;
                }
            }
        }
        
        self
    }
    
    // Подсчет живых клеток
    pub fn alive_count(&self) -> usize {
        let mut count = 0;
        
        for row in &self.cells {
            for cell in row {
                if cell.is_alive() {
                    count += 1;
                }
            }
        }
        
        count
    }
    
    // Вычисление хэша состояния
    pub fn compute_hash(&self) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        
        let mut hasher = DefaultHasher::new();
        
        // Хэшируем построчно
        for row in &self.cells {
            for cell in row {
                cell.is_alive().hash(&mut hasher);
            }
        }
        
        hasher.finish()
    }
}

// БЕНЧМАРК Game of Life
pub struct GameOfLife {
    iterations: i32,
    result: i64,
    grid: Grid,
}

impl GameOfLife {
    pub fn new() -> Self {
        let name = "GameOfLife".to_string();
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(1000);
        
        let width = 256;
        let height = 256;
        
        // Создаем и инициализируем сетку
        let grid = Grid::new(width, height);
        
        Self {
            iterations,
            result: 0,
            grid,
        }
    }
    
    // Простой шаг симуляции
    fn simulate_step(&mut self) {
        self.grid = self.grid.next_generation();
    }
}

impl Benchmark for GameOfLife {
    fn name(&self) -> String {
        "GameOfLife".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.iterations
    }
    
    fn run(&mut self) {
        // Инициализация случайными клетками
        for y in 0..self.grid.height {
            for x in 0..self.grid.width {
                if helper::next_float(1.0) < 0.1 {
                    self.grid.set(x, y, Cell::Alive);
                }
            }
        }
        
        // Основной цикл симуляции
        for _ in 0..self.iterations {
            self.simulate_step();
        }
        
        let alive_count = self.grid.alive_count();        
        self.result = alive_count as i64;
    }
    
    fn result(&self) -> i64 {
        self.result
    }
}