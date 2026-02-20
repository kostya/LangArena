module game_of_life

import benchmark
import helper

struct Cell {
mut:
	alive      bool
	next_state bool
	neighbors  []&Cell
}

fn new_cell() &Cell {
	return &Cell{
		alive:      false
		next_state: false
		neighbors:  unsafe { []&Cell{} }
	}
}

fn (mut cell Cell) add_neighbor(neighbor &Cell) {
	cell.neighbors << neighbor
}

fn (mut cell Cell) compute_next_state() {
	mut alive_neighbors := 0
	for neighbor in cell.neighbors {
		if neighbor.alive {
			alive_neighbors++
		}
	}

	if cell.alive {
		cell.next_state = alive_neighbors == 2 || alive_neighbors == 3
	} else {
		cell.next_state = alive_neighbors == 3
	}
}

fn (mut cell Cell) update() {
	cell.alive = cell.next_state
}

struct Grid {
mut:
	width  int
	height int
	cells  [][]&Cell
}

fn new_grid(width int, height int) &Grid {
	unsafe {
		mut cells := [][]&Cell{len: height}
		for y in 0 .. height {
			cells[y] = []&Cell{len: width}
		}

		for y in 0 .. height {
			for x in 0 .. width {
				cells[y][x] = new_cell()
			}
		}

		mut grid := &Grid{
			width:  width
			height: height
			cells:  cells
		}

		grid.link_neighbors()
		return grid
	}
}

fn (mut grid Grid) link_neighbors() {
	for y in 0 .. grid.height {
		for x in 0 .. grid.width {
			mut cell := grid.cells[y][x]

			for dy in -1 .. 2 {
				for dx in -1 .. 2 {
					if dx == 0 && dy == 0 {
						continue
					}

					ny := (y + dy + grid.height) % grid.height
					nx := (x + dx + grid.width) % grid.width

					cell.add_neighbor(grid.cells[ny][nx])
				}
			}
		}
	}
}

fn (mut grid Grid) next_generation() {
	for mut row in grid.cells {
		for mut cell in row {
			cell.compute_next_state()
		}
	}

	for mut row in grid.cells {
		for mut cell in row {
			cell.update()
		}
	}
}

fn (grid Grid) count_alive() int {
	mut count := 0
	for row in grid.cells {
		for cell in row {
			if cell.alive {
				count++
			}
		}
	}
	return count
}

const fnv_offset_basis = u32(2166136261)
const fnv_prime = u32(16777619)

fn (grid Grid) compute_hash() u32 {
	mut hash := fnv_offset_basis
	for row in grid.cells {
		for cell in row {
			alive := u32(cell.alive)
			hash = (hash ^ alive) * fnv_prime
		}
	}
	return hash
}

pub struct GameOfLife {
	benchmark.BaseBenchmark
mut:
	width  int
	height int
	grid   &Grid
}

pub fn new_gameoflife() &benchmark.IBenchmark {
	mut bench := &GameOfLife{
		BaseBenchmark: benchmark.new_base_benchmark('GameOfLife')
		width:         0
		height:        0
		grid:          unsafe { nil }
	}
	return bench
}

pub fn (b GameOfLife) name() string {
	return 'GameOfLife'
}

pub fn (mut b GameOfLife) prepare() {
	b.width = int(helper.config_i64('GameOfLife', 'w'))
	b.height = int(helper.config_i64('GameOfLife', 'h'))
	b.grid = new_grid(b.width, b.height)

	for row in b.grid.cells {
		for cell in row {
			if helper.next_float(1.0) < 0.1 {
				unsafe {
					cell.alive = true
				}
			}
		}
	}
}

pub fn (mut b GameOfLife) run(iteration_id int) {
	b.grid.next_generation()
}

pub fn (b GameOfLife) checksum() u32 {
	alive := b.grid.count_alive()
	return b.grid.compute_hash() + u32(alive)
}
