namespace game_of_life;

import std;
import bench;
import helper;

struct Cell {
    alive: bool,
    next_state: bool,
    neighbors: (Cell&<u32>)[..8],
}

fn new_cell(alive: bool) -> Cell {
    return Cell { alive: alive, next_state: false, neighbors: [] };
}

fn add_neighbor(c: Cell&, cell: Cell&) { c.neighbors.push(cell); }

fn compute_next_state(c: Cell&) {
    let alive_neighbors = count(c.neighbors) { it.alive };
    c.next_state = if c.alive {
        alive_neighbors == 2 || alive_neighbors == 3
    } else {
        alive_neighbors == 3
    };
}

fn update(c: Cell&) { c.alive = c.next_state; }

struct Grid { width: i64, height: i64, cells: (Cell[:])[>..] }

fn new_grid(pool: Cell[>..]&, width: i64, height: i64) -> Grid {
    var grid = Grid { width: width, height: height, cells: [] };
    for y in height {
        let row = pool.alloc_slice(width);
        for &cell in row { cell = new_cell(false); }
        grid.cells.push(row);
    }

    fn link_neighbors() {
        for y in grid.height {
            for x in grid.width {
                let cell .= grid.cells[y][x];
                for dy in -1..2 {
                    for dx in -1..2 {
                        if dx == 0 && dy == 0 { continue; }

                        let ny = (y + dy + grid.height) % grid.height;
                        let nx = (x + dx + grid.width) % grid.width;

                        cell.add_neighbor(grid.cells[ny][nx]);
                    }
                }
            }
        }
    }

    link_neighbors();
    return grid;
}

fn next_generation(grid: Grid&) {
    for row in grid.cells {
        for &cell in row { cell.compute_next_state(); }
    }
    for row in grid.cells {
        for &cell in row { cell.update(); }
    }
}

fn count_alive(grid: Grid&) -> u32 {
    var count: u32 = 0;
    for row in grid.cells {
        for &cell in row {
            if cell.alive { count++; }
        }
    }
    return count;
}

fn compute_hash(grid: Grid&) -> u32 {
    let FNV_OFFSET_BASIS: u32 = 2166136261;
    let FNV_PRIME: u32 = 16777619;
    var hash = FNV_OFFSET_BASIS;
    for row in grid.cells {
        for &cell in row {
            let alive: u32 = if cell.alive { 1 } else { 0 };
            hash = (hash ^ alive) * FNV_PRIME;
        }
    }
    return hash;
}

struct GameOfLife { grid: Grid }

fn new_game_of_life(pool: Cell[>..]&) -> GameOfLife {
    let width = config_i64("Etc::GameOfLife", "w");
    let height = config_i64("Etc::GameOfLife", "h");
    return GameOfLife { grid: new_grid(pool, width, height) };
}

fn prepare(s: GameOfLife&) {
    for row in s.grid.cells {
        for &cell in row {
            if next_float(1.0) < 0.1 { cell.alive = true; }
        }
    }
}

fn run(s: GameOfLife&, iteration_id: i64) { s.grid.next_generation(); }

fn checksum(s: GameOfLife&) -> u32 {
    let alive = s.grid.count_alive();
    return s.grid.compute_hash() + alive;
}