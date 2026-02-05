module game_of_life

import benchmark
import helper

enum Cell {
	dead  = 0
	alive = 1
}

struct Grid {
pub:
	width  int
	height int
mut:
	cells  []Cell
	buffer []Cell
}

fn new_grid(width int, height int) Grid {
	size := width * height
	return Grid{
		width:  width
		height: height
		cells:  []Cell{len: size, init: .dead}
		buffer: []Cell{len: size, init: .dead}
	}
}

fn (grid Grid) get(x int, y int) Cell {
	return grid.cells[y * grid.width + x]
}

fn (mut grid Grid) set(x int, y int, cell Cell) {
	grid.cells[y * grid.width + x] = cell
}

fn (grid Grid) count_neighbors(x int, y int) int {
	width := grid.width
	height := grid.height

	y_prev := if y == 0 { height - 1 } else { y - 1 }
	y_next := if y == height - 1 { 0 } else { y + 1 }
	x_prev := if x == 0 { width - 1 } else { x - 1 }
	x_next := if x == width - 1 { 0 } else { x + 1 }

	mut count := 0
	cells := grid.cells

	count += int(cells[y_prev * width + x_prev] == .alive)
	count += int(cells[y_prev * width + x] == .alive)
	count += int(cells[y_prev * width + x_next] == .alive)
	count += int(cells[y * width + x_prev] == .alive)
	count += int(cells[y * width + x_next] == .alive)
	count += int(cells[y_next * width + x_prev] == .alive)
	count += int(cells[y_next * width + x] == .alive)
	count += int(cells[y_next * width + x_next] == .alive)

	return count
}

fn (mut grid Grid) next_generation() {
	width := grid.width
	height := grid.height

	cells := grid.cells
	mut buffer := grid.buffer.clone()

	for y in 0 .. height {
		y_idx := y * width

		for x in 0 .. width {
			idx := y_idx + x

			neighbors := grid.count_neighbors(x, y)

			current := cells[idx]
			mut next_state := Cell.dead

			if current == .alive {
				next_state = if neighbors == 2 || neighbors == 3 { .alive } else { .dead }
			} else {
				next_state = if neighbors == 3 { .alive } else { .dead }
			}

			buffer[idx] = next_state
		}
	}

	grid.cells = buffer
}

const fnv_offset_basis = u32(2166136261)
const fnv_prime = u32(16777619)

fn (grid Grid) compute_hash() u32 {
	mut hash := fnv_offset_basis

	for i in 0 .. grid.cells.len {
		alive := u32(grid.cells[i] == .alive)
		hash = (hash ^ alive) * fnv_prime
	}

	return hash
}

pub struct GameOfLife {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	grid       Grid
}

pub fn new_gameoflife() &benchmark.IBenchmark {
	mut bench := &GameOfLife{
		BaseBenchmark: benchmark.new_base_benchmark('GameOfLife')
		result_val:    0
		width:         0
		height:        0
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

	for y in 0 .. b.height {
		for x in 0 .. b.width {
			if helper.next_float(1.0) < 0.1 {
				b.grid.set(x, y, .alive)
			}
		}
	}
}

pub fn (mut b GameOfLife) run(iteration_id int) {
	_ = iteration_id
	b.grid.next_generation()
}

pub fn (b GameOfLife) checksum() u32 {
	return b.grid.compute_hash()
}