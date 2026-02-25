use super::super::{helper, Benchmark};
use crate::config_i64;
use std::cmp::Reverse;
use std::collections::BinaryHeap;
use std::collections::VecDeque;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CellKind {
    Wall = 0,
    Space,
    Start,
    Finish,
    Border,
    Path,
}

impl CellKind {
    fn is_walkable(&self) -> bool {
        matches!(self, CellKind::Space | CellKind::Start | CellKind::Finish)
    }

    fn value(&self) -> u32 {
        *self as u32
    }
}

pub struct Cell {
    kind: CellKind,
    neighbors: [(usize, usize); 4],
    pub x: usize,
    pub y: usize,
}

impl Cell {
    fn new(x: usize, y: usize) -> Self {
        Self {
            kind: CellKind::Wall,
            neighbors: [(0, 0); 4],
            x,
            y,
        }
    }

    fn reset(&mut self) {
        if self.kind == CellKind::Space {
            self.kind = CellKind::Wall;
        }
    }
}

pub struct Maze {
    width: usize,
    height: usize,
    cells: Vec<Vec<Cell>>,
}

impl Maze {
    pub fn new(width: usize, height: usize) -> Self {
        let width = width.max(5);
        let height = height.max(5);

        let mut cells = Vec::with_capacity(height);
        for y in 0..height {
            let mut row = Vec::with_capacity(width);
            for x in 0..width {
                row.push(Cell::new(x, y));
            }
            cells.push(row);
        }

        let mut maze = Maze {
            width,
            height,
            cells,
        };

        maze.link_neighbors();
        maze
    }

    fn link_neighbors(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                if x == 0 || y == 0 || x == self.width - 1 || y == self.height - 1 {
                    self.cells[y][x].kind = CellKind::Border;
                }
            }
        }

        for y in 1..self.height - 1 {
            for x in 1..self.width - 1 {
                let mut neighbors = [(y - 1, x), (y + 1, x), (y, x + 1), (y, x - 1)];

                for _ in 0..4 {
                    let i = helper::next_int(4) as usize;
                    let j = helper::next_int(4) as usize;
                    if i != j {
                        neighbors.swap(i, j);
                    }
                }

                self.cells[y][x].neighbors = neighbors;
            }
        }

        self.cells[1][1].kind = CellKind::Start;
        self.cells[self.height - 2][self.width - 2].kind = CellKind::Finish;
    }

    pub fn reset(&mut self) {
        for row in &mut self.cells {
            for cell in row {
                cell.reset();
            }
        }
        self.cells[1][1].kind = CellKind::Start;
        self.cells[self.height - 2][self.width - 2].kind = CellKind::Finish;
    }

    fn dig(&mut self, start: (usize, usize)) {
        let mut stack = Vec::new();
        stack.push(start);

        while let Some((y, x)) = stack.pop() {
            let walkable_neighbors = self.cells[y][x]
                .neighbors
                .iter()
                .filter(|&&(ny, nx)| self.cells[ny][nx].kind.is_walkable())
                .count();

            if walkable_neighbors == 1 {
                self.cells[y][x].kind = CellKind::Space;

                for &(ny, nx) in &self.cells[y][x].neighbors {
                    if self.cells[ny][nx].kind == CellKind::Wall {
                        stack.push((ny, nx));
                    }
                }
            }
        }
    }

    fn ensure_open_finish(&mut self, pos: (usize, usize)) {
        let (y, x) = pos;
        self.cells[y][x].kind = CellKind::Space;

        let neighbors_to_check: Vec<(usize, usize)> = self.cells[y][x]
            .neighbors
            .iter()
            .filter(|&&(ny, nx)| self.cells[ny][nx].kind == CellKind::Wall)
            .copied()
            .collect();

        let walkable_neighbors = self.cells[y][x]
            .neighbors
            .iter()
            .filter(|&&(ny, nx)| self.cells[ny][nx].kind.is_walkable())
            .count();

        if walkable_neighbors > 1 {
            return;
        }

        for neighbor_pos in neighbors_to_check {
            self.ensure_open_finish(neighbor_pos);
        }
    }

    pub fn generate(&mut self) {
        let start_neighbors = self.cells[1][1].neighbors;

        for &(ny, nx) in &start_neighbors {
            if self.cells[ny][nx].kind == CellKind::Wall {
                self.dig((ny, nx));
            }
        }

        let finish_pos = (self.height - 2, self.width - 2);
        let finish_neighbors = self.cells[finish_pos.0][finish_pos.1].neighbors;

        for &(ny, nx) in &finish_neighbors {
            if self.cells[ny][nx].kind == CellKind::Wall {
                self.ensure_open_finish((ny, nx));
            }
        }
    }

    pub fn middle_cell(&self) -> &Cell {
        &self.cells[self.height / 2][self.width / 2]
    }

    pub fn checksum(&self) -> u32 {
        let mut hasher = 2166136261u32;
        let prime = 16777619u32;

        for row in &self.cells {
            for cell in row {
                if cell.kind == CellKind::Space {
                    let val = (cell.x * cell.y) as u32;
                    hasher = (hasher ^ val).wrapping_mul(prime);
                }
            }
        }
        hasher
    }

    pub fn print_to_console(&self) {
        for row in &self.cells {
            for cell in row {
                match cell.kind {
                    CellKind::Space => print!(" "),
                    CellKind::Wall => print!("\x1b[34m#\x1b[0m"),
                    CellKind::Border => print!("\x1b[31mO\x1b[0m"),
                    CellKind::Start => print!("\x1b[32m>\x1b[0m"),
                    CellKind::Finish => print!("\x1b[32m<\x1b[0m"),
                    CellKind::Path => print!("\x1b[33m.\x1b[0m"),
                }
            }
            println!();
        }
        println!();
    }

    pub fn get_start(&self) -> (usize, usize) {
        (1, 1)
    }

    pub fn get_finish(&self) -> (usize, usize) {
        (self.height - 2, self.width - 2)
    }

    pub fn get_cell(&self, y: usize, x: usize) -> &Cell {
        &self.cells[y][x]
    }

    pub fn get_cell_mut(&mut self, y: usize, x: usize) -> &mut Cell {
        &mut self.cells[y][x]
    }

    pub fn width(&self) -> usize {
        self.width
    }
    pub fn height(&self) -> usize {
        self.height
    }
}

pub struct MazeGenerator {
    width: i32,
    height: i32,
    maze: Maze,
    result_val: u32,
}

impl MazeGenerator {
    pub fn new() -> Self {
        let width = config_i64("Maze::Generator", "w") as i32;
        let height = config_i64("Maze::Generator", "h") as i32;
        let maze = Maze::new(width as usize, height as usize);

        Self {
            width,
            height,
            maze,
            result_val: 0,
        }
    }
}

impl Benchmark for MazeGenerator {
    fn name(&self) -> String {
        "Maze::Generator".to_string()
    }

    fn prepare(&mut self) {}

    fn run(&mut self, _iteration_id: i64) {
        self.maze.reset();
        self.maze.generate();
        self.result_val = self
            .result_val
            .wrapping_add(self.maze.middle_cell().kind.value());
    }

    fn checksum(&self) -> u32 {
        self.result_val.wrapping_add(self.maze.checksum())
    }
}

pub struct MazeBFS {
    width: i32,
    height: i32,
    maze: Maze,
    path: Vec<(usize, usize)>,
    result_val: u32,
}

impl MazeBFS {
    pub fn new() -> Self {
        let width = config_i64("Maze::BFS", "w") as i32;
        let height = config_i64("Maze::BFS", "h") as i32;
        let maze = Maze::new(width as usize, height as usize);

        Self {
            width,
            height,
            maze,
            path: Vec::new(),
            result_val: 0,
        }
    }

    fn bfs(&self, start: (usize, usize), target: (usize, usize)) -> Vec<(usize, usize)> {
        if start == target {
            return vec![start];
        }

        let width = self.maze.width();
        let height = self.maze.height();

        let mut queue = VecDeque::new();
        let mut visited = vec![vec![false; width]; height];
        let mut path = Vec::new();

        visited[start.0][start.1] = true;
        path.push((start.0, start.1, -1i32));
        queue.push_back(0);

        while let Some(path_id) = queue.pop_front() {
            let (y, x, _) = path[path_id];

            for &(ny, nx) in &self.maze.get_cell(y, x).neighbors {
                if (ny, nx) == target {
                    let mut result = vec![target];
                    let mut current = path_id as i32;
                    while current >= 0 {
                        let (py, px, _) = path[current as usize];
                        result.push((py, px));
                        current = path[current as usize].2;
                    }
                    result.reverse();
                    return result;
                }

                if self.maze.get_cell(ny, nx).kind.is_walkable() && !visited[ny][nx] {
                    visited[ny][nx] = true;
                    path.push((ny, nx, path_id as i32));
                    queue.push_back(path.len() - 1);
                }
            }
        }

        Vec::new()
    }
}

impl Benchmark for MazeBFS {
    fn name(&self) -> String {
        "Maze::BFS".to_string()
    }

    fn prepare(&mut self) {
        self.maze.generate();
    }

    fn run(&mut self, _iteration_id: i64) {
        self.path = self.bfs(self.maze.get_start(), self.maze.get_finish());
        self.result_val = self.result_val.wrapping_add(self.path.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let mid_cell_value = if !self.path.is_empty() {
            let mid_index = self.path.len() / 2;
            let (y, x) = self.path[mid_index];
            (x * y) as u32
        } else {
            0
        };

        self.result_val.wrapping_add(mid_cell_value)
    }
}

pub struct MazeAStar {
    width: i32,
    height: i32,
    maze: Maze,
    path: Vec<(usize, usize)>,
    result_val: u32,
}

impl MazeAStar {
    pub fn new() -> Self {
        let width = config_i64("Maze::AStar", "w") as i32;
        let height = config_i64("Maze::AStar", "h") as i32;
        let maze = Maze::new(width as usize, height as usize);

        Self {
            width,
            height,
            maze,
            path: Vec::new(),
            result_val: 0,
        }
    }

    fn heuristic(&self, a: (usize, usize), b: (usize, usize)) -> i32 {
        (a.0 as i32 - b.0 as i32).abs() + (a.1 as i32 - b.1 as i32).abs()
    }

    fn astar(&self, start: (usize, usize), target: (usize, usize)) -> Vec<(usize, usize)> {
        if start == target {
            return vec![start];
        }

        let width = self.maze.width();
        let height = self.maze.height();
        let size = width * height;

        let idx = |y: usize, x: usize| y * width + x;

        let start_idx = idx(start.0, start.1);
        let target_idx = idx(target.0, target.1);

        let mut came_from = vec![-1i32; size];
        let mut g_score = vec![i32::MAX; size];
        let mut f_score = vec![i32::MAX; size];

        let mut open_set = BinaryHeap::new();

        let mut in_open = vec![false; size];

        g_score[start_idx] = 0;
        f_score[start_idx] = self.heuristic(start, target);
        open_set.push(Reverse((f_score[start_idx], start_idx)));
        in_open[start_idx] = true;

        while let Some(Reverse((_, current_idx))) = open_set.pop() {
            in_open[current_idx] = false;

            if g_score[current_idx] == i32::MAX {
                continue;
            }

            if current_idx == target_idx {
                let mut path = Vec::new();
                let mut cur = current_idx as i32;
                while cur != -1 {
                    let y = (cur as usize) / width;
                    let x = (cur as usize) % width;
                    path.push((y, x));
                    cur = came_from[cur as usize];
                }
                path.reverse();
                return path;
            }

            let current_y = current_idx / width;
            let current_x = current_idx % width;
            let current_g = g_score[current_idx];

            for &(ny, nx) in &self.maze.get_cell(current_y, current_x).neighbors {
                if !self.maze.get_cell(ny, nx).kind.is_walkable() {
                    continue;
                }

                let neighbor_idx = idx(ny, nx);
                let tentative_g = current_g + 1;

                if tentative_g < g_score[neighbor_idx] {
                    came_from[neighbor_idx] = current_idx as i32;
                    g_score[neighbor_idx] = tentative_g;
                    f_score[neighbor_idx] = tentative_g + self.heuristic((ny, nx), target);

                    if !in_open[neighbor_idx] {
                        open_set.push(Reverse((f_score[neighbor_idx], neighbor_idx)));
                        in_open[neighbor_idx] = true;
                    } else {
                        open_set.push(Reverse((f_score[neighbor_idx], neighbor_idx)));
                    }
                }
            }
        }

        Vec::new()
    }
}

impl Benchmark for MazeAStar {
    fn name(&self) -> String {
        "Maze::AStar".to_string()
    }

    fn prepare(&mut self) {
        self.maze.generate();
    }

    fn run(&mut self, _iteration_id: i64) {
        self.path = self.astar(self.maze.get_start(), self.maze.get_finish());
        self.result_val = self.result_val.wrapping_add(self.path.len() as u32);
    }

    fn checksum(&self) -> u32 {
        let mid_cell_value = if !self.path.is_empty() {
            let mid_index = self.path.len() / 2;
            let (y, x) = self.path[mid_index];
            (x * y) as u32
        } else {
            0
        };

        self.result_val.wrapping_add(mid_cell_value)
    }
}
