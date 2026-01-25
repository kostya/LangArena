use super::super::{Benchmark, INPUT, helper};
use std::collections::VecDeque;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Cell {
    Wall,
    Path,
}

impl Cell {
    #[inline]
    fn is_walkable(&self) -> bool {
        matches!(self, Cell::Path)
    }
}

pub struct Maze {
    width: usize,
    height: usize,
    cells: Vec<Vec<Cell>>,
}

impl Maze {
    pub fn new(width: usize, height: usize) -> Self {
        // Гарантируем минимальный размер
        let width = width.max(5);
        let height = height.max(5);
        
        let cells = vec![vec![Cell::Wall; width]; height];
        Self { width, height, cells }
    }
    
    #[inline]
    pub fn get(&self, x: usize, y: usize) -> Cell {
        self.cells[y][x]
    }
    
    #[inline]
    pub fn get_mut(&mut self, x: usize, y: usize) -> &mut Cell {
        &mut self.cells[y][x]
    }
    
    pub fn generate(&mut self) {
        // Убеждаемся что есть место для деления
        if self.width < 5 || self.height < 5 {
            // Слишком маленький для рекурсивного деления
            // Создаем простой проход
            for x in 0..self.width {
                *self.get_mut(x, self.height / 2) = Cell::Path;
            }
            return;
        }
        
        self.divide(0, 0, self.width - 1, self.height - 1);
    }
    
    fn divide(&mut self, x1: usize, y1: usize, x2: usize, y2: usize) {
        let width = x2 - x1;
        let height = y2 - y1;
        
        // Базовый случай: область слишком мала
        if width < 2 || height < 2 {
            return;
        }
        
        // ВАЖНО: Защита от деления на ноль
        let width_for_wall = width.saturating_sub(2);
        let height_for_wall = height.saturating_sub(2);
        let width_for_hole = width.saturating_sub(1);
        let height_for_hole = height.saturating_sub(1);
        
        if width_for_wall == 0 || height_for_wall == 0 || 
           width_for_hole == 0 || height_for_hole == 0 {
            return;
        }
        
        if width > height {
            // ВЕРТИКАЛЬНАЯ СТЕНА
            
            // Безопасный расчет wall_x
            let wall_range = (width_for_wall / 2).max(1);
            let wall_offset = if wall_range > 0 {
                (helper::next_int(wall_range as i32) as usize) * 2
            } else {
                0
            };
            let wall_x = x1 + 2 + wall_offset;
            
            // Безопасный расчет hole_y
            let hole_range = (height_for_hole / 2).max(1);
            let hole_offset = if hole_range > 0 {
                (helper::next_int(hole_range as i32) as usize) * 2
            } else {
                0
            };
            let hole_y = y1 + 1 + hole_offset;
            
            // Проверяем границы
            if wall_x > x2 || hole_y > y2 {
                return;
            }
            
            for y in y1..=y2 {
                if y != hole_y {
                    *self.get_mut(wall_x, y) = Cell::Wall;
                }
            }
            
            // Рекурсивное деление слева и справа от стены
            if wall_x > x1 + 1 {
                self.divide(x1, y1, wall_x - 1, y2);
            }
            if wall_x + 1 < x2 {
                self.divide(wall_x + 1, y1, x2, y2);
            }
        } else {
            // ГОРИЗОНТАЛЬНАЯ СТЕНА
            
            // Безопасный расчет wall_y
            let wall_range = (height_for_wall / 2).max(1);
            let wall_offset = if wall_range > 0 {
                (helper::next_int(wall_range as i32) as usize) * 2
            } else {
                0
            };
            let wall_y = y1 + 2 + wall_offset;
            
            // Безопасный расчет hole_x
            let hole_range = (width_for_hole / 2).max(1);
            let hole_offset = if hole_range > 0 {
                (helper::next_int(hole_range as i32) as usize) * 2
            } else {
                0
            };
            let hole_x = x1 + 1 + hole_offset;
            
            // Проверяем границы
            if wall_y > y2 || hole_x > x2 {
                return;
            }
            
            for x in x1..=x2 {
                if x != hole_x {
                    *self.get_mut(x, wall_y) = Cell::Wall;
                }
            }
            
            // Рекурсивное деление сверху и снизу от стены
            if wall_y > y1 + 1 {
                self.divide(x1, y1, x2, wall_y - 1);
            }
            if wall_y + 1 < y2 {
                self.divide(x1, wall_y + 1, x2, y2);
            }
        }
    }
    
    pub fn to_bool_grid(&self) -> Vec<Vec<bool>> {
        self.cells.iter()
            .map(|row| row.iter().map(|cell| cell.is_walkable()).collect())
            .collect()
    }
    
    pub fn generate_walkable_maze(width: usize, height: usize) -> Vec<Vec<bool>> {
        let mut maze = Maze::new(width, height);
        maze.generate();
        
        // Гарантируем проходимость
        let start = (1, 1);
        let end = (width - 2, height - 2);
        
        if !maze.is_connected(start, end) {
            // Делаем простой проход если лабиринт не связный
            for x in 0..width {
                if x < maze.width {
                    for y in 0..height {
                        if y < maze.height {
                            if x == 1 || y == 1 || x == width - 2 || y == height - 2 {
                                *maze.get_mut(x, y) = Cell::Path;
                            }
                        }
                    }
                }
            }
        }
        
        maze.to_bool_grid()
    }
    
    // Проверка связности
    fn is_connected(&self, start: (usize, usize), end: (usize, usize)) -> bool {
        if start.0 >= self.width || start.1 >= self.height ||
           end.0 >= self.width || end.1 >= self.height {
            return false;
        }
        
        let mut visited = vec![vec![false; self.width]; self.height];
        let mut queue = VecDeque::new();
        
        visited[start.1][start.0] = true;
        queue.push_back(start);
        
        while let Some((x, y)) = queue.pop_front() {
            if (x, y) == end {
                return true;
            }
            
            // Верх
            if y > 0 && self.get(x, y - 1).is_walkable() && !visited[y - 1][x] {
                visited[y - 1][x] = true;
                queue.push_back((x, y - 1));
            }
            
            // Право
            if x + 1 < self.width && self.get(x + 1, y).is_walkable() && !visited[y][x + 1] {
                visited[y][x + 1] = true;
                queue.push_back((x + 1, y));
            }
            
            // Низ
            if y + 1 < self.height && self.get(x, y + 1).is_walkable() && !visited[y + 1][x] {
                visited[y + 1][x] = true;
                queue.push_back((x, y + 1));
            }
            
            // Лево
            if x > 0 && self.get(x - 1, y).is_walkable() && !visited[y][x - 1] {
                visited[y][x - 1] = true;
                queue.push_back((x - 1, y));
            }
        }
        
        false
    }
}

pub struct MazeGenerator {
    iterations: i32,
    result: i64,
    width: usize,
    height: usize,
}

impl MazeGenerator {
    pub fn new() -> Self {
        let name = "MazeGenerator".to_string();
        
        let iterations: i32 = INPUT.get()
            .unwrap()
            .get(&name)
            .and_then(|s| s.parse().ok())
            .unwrap_or(10);  // Меньше итераций для больших размеров
        
        Self {
            iterations,
            result: 0,
            width: 1001,
            height: 1001,
        }
    }
}

impl Benchmark for MazeGenerator {
    fn name(&self) -> String {
        "MazeGenerator".to_string()
    }
    
    fn iterations(&self) -> i32 {
        self.iterations
    }
    
    fn run(&mut self) {
        let mut checksum = 0_u64;
        
        for i in 0..self.iterations {
            // Используем ТУ ЖЕ функцию что и AStarPathfinder!
            let bool_grid = Maze::generate_walkable_maze(self.width, self.height);


            for (y, row) in bool_grid.iter().enumerate() {
                for (x, &cell) in row.iter().enumerate() {
                    if !cell {
                        checksum += (x * y) as u64;
                    }
                }
            }            
        }
        
        self.result = checksum as i64;
    }

    fn result(&self) -> i64 {
        self.result
    }
}