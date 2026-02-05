use super::super::{Benchmark, helper};
use crate::config_i64;
use super::maze_generator::Maze;
use std::cmp::Ordering;
use std::collections::BinaryHeap as StdBinaryHeap;

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

pub struct AStarPathfinder {
    start_x: i32,
    start_y: i32,
    goal_x: i32,
    goal_y: i32,
    width: i32,
    height: i32,
    maze_grid: Vec<Vec<bool>>,
    result_val: u32,

    g_scores_cache: Vec<i32>,
    came_from_cache: Vec<i32>, 
}

impl AStarPathfinder {

    #[inline]
    fn distance(a_x: i32, a_y: i32, b_x: i32, b_y: i32) -> i32 {
        (a_x - b_x).abs() + (a_y - b_y).abs()
    }

    #[inline]
    fn pack_coords(x: i32, y: i32, width: i32) -> i32 {
        y * width + x
    }

    #[inline]
    fn unpack_coords(packed: i32, width: i32) -> (i32, i32) {
        (packed % width, packed / width)
    }

    pub fn new() -> Self {
        let width = config_i64("AStarPathfinder", "w") as i32;
        let height = config_i64("AStarPathfinder", "h") as i32;
        let start_x = 1;
        let start_y = 1;
        let goal_x = width - 2;
        let goal_y = height - 2;

        let size = (width * height) as usize;

        Self {
            start_x,
            start_y,
            goal_x,
            goal_y,
            width,
            height,
            maze_grid: Vec::new(),
            result_val: 0,
            g_scores_cache: Vec::with_capacity(size),
            came_from_cache: Vec::with_capacity(size),
        }
    }

    fn find_path(&mut self) -> (Option<Vec<(i32, i32)>>, i32) {
        let grid = &self.maze_grid;
        let width = self.width;
        let height = self.height;
        let start_x = self.start_x;
        let start_y = self.start_y;
        let goal_x = self.goal_x;
        let goal_y = self.goal_y;

        let g_scores = &mut self.g_scores_cache;
        let came_from = &mut self.came_from_cache;

        let size = (width * height) as usize;
        g_scores.resize(size, i32::MAX);
        came_from.resize(size, -1);

        for i in 0..size {
            g_scores[i] = i32::MAX;
            came_from[i] = -1;
        }

        let mut open_set = StdBinaryHeap::with_capacity(size);
        let mut nodes_explored = 0;

        let start_idx = Self::pack_coords(start_x, start_y, width) as usize;
        g_scores[start_idx] = 0;

        open_set.push(Node::new(
            start_x,
            start_y,
            Self::distance(start_x, start_y, goal_x, goal_y)
        ));

        static DIRECTIONS: [(i32, i32); 4] = [(0, -1), (1, 0), (0, 1), (-1, 0)];

        while let Some(current) = open_set.pop() {
            nodes_explored += 1;

            if current.x == goal_x && current.y == goal_y {

                let mut path = Vec::with_capacity(size);
                let mut x = current.x;
                let mut y = current.y;

                while x != start_x || y != start_y {
                    path.push((x, y));
                    let idx = Self::pack_coords(x, y, width) as usize;
                    let packed = came_from[idx];
                    if packed == -1 {
                        break;
                    }
                    let (px, py) = Self::unpack_coords(packed, width);
                    x = px;
                    y = py;
                }

                path.push((start_x, start_y));
                path.reverse();
                return (Some(path), nodes_explored);
            }

            let current_idx = Self::pack_coords(current.x, current.y, width) as usize;
            let current_g = g_scores[current_idx];

            for &(dx, dy) in &DIRECTIONS {
                let nx = current.x + dx;
                let ny = current.y + dy;

                if nx < 0 || ny < 0 || nx >= width || ny >= height {
                    continue;
                }

                let nx_usize = nx as usize;
                let ny_usize = ny as usize;

                if !grid[ny_usize][nx_usize] {
                    continue;
                }

                let tentative_g = current_g + 1000;
                let neighbor_idx = Self::pack_coords(nx, ny, width) as usize;

                if tentative_g < g_scores[neighbor_idx] {

                    came_from[neighbor_idx] = current_idx as i32;
                    g_scores[neighbor_idx] = tentative_g;

                    let f_score = tentative_g + Self::distance(nx, ny, goal_x, goal_y);
                    open_set.push(Node::new(nx, ny, f_score));
                }
            }
        }

        (None, nodes_explored)
    }
}

impl Benchmark for AStarPathfinder {
    fn name(&self) -> String {
        "AStarPathfinder".to_string()
    }

    fn prepare(&mut self) {
        self.maze_grid = Maze::generate_walkable_maze(self.width as usize, self.height as usize);
    }

    fn run(&mut self, _iteration_id: i64) {
        let (path, nodes_explored) = self.find_path();

        let mut local_result: u32 = 0;

        local_result = path.as_ref().map(|p| p.len()).unwrap_or(0) as u32;

        local_result = local_result.wrapping_shl(5).wrapping_add(nodes_explored as u32);

        self.result_val = self.result_val.wrapping_add(local_result);
    }

    fn checksum(&self) -> u32 {
        self.result_val
    }
}