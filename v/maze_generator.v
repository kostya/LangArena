module maze_generator

import benchmark
import helper

enum MazeCell {
	wall
	path
}

struct Maze {
pub:
	width  int
	height int
mut:
	cells [][]MazeCell
}

fn new_maze(width int, height int) Maze {

	actual_width := if width > 5 { width } else { 5 }
	actual_height := if height > 5 { height } else { 5 }

	mut cells := [][]MazeCell{len: actual_height}
	for i in 0 .. actual_height {
		cells[i] = []MazeCell{len: actual_width, init: .wall}
	}

	return Maze{
		width:  actual_width
		height: actual_height
		cells:  cells
	}
}

fn (m Maze) get(x int, y int) MazeCell {
	return m.cells[y][x]
}

fn (mut m Maze) set(x int, y int, cell MazeCell) {
	m.cells[y][x] = cell
}

fn (mut m Maze) add_random_paths() {
	num_extra_paths := (m.width * m.height) / 20 

	for _ in 0 .. num_extra_paths {
		x := helper.next_int(m.width - 2) + 1 
		y := helper.next_int(m.height - 2) + 1

		if m.get(x, y) == .wall && m.get(x - 1, y) == .wall && m.get(x + 1, y) == .wall
			&& m.get(x, y - 1) == .wall && m.get(x, y + 1) == .wall {
			m.set(x, y, .path)
		}
	}
}

fn (mut m Maze) divide(x1 int, y1 int, x2 int, y2 int) {
	width := x2 - x1
	height := y2 - y1

	if width < 2 || height < 2 {
		return
	}

	width_for_wall := if width - 2 > 0 { width - 2 } else { 0 }
	height_for_wall := if height - 2 > 0 { height - 2 } else { 0 }
	width_for_hole := if width - 1 > 0 { width - 1 } else { 0 }
	height_for_hole := if height - 1 > 0 { height - 1 } else { 0 }

	if width_for_wall == 0 || height_for_wall == 0 || width_for_hole == 0 || height_for_hole == 0 {
		return
	}

	if width > height {

		wall_range := if width_for_wall / 2 > 1 { width_for_wall / 2 } else { 1 }
		wall_offset := if wall_range > 0 { helper.next_int(wall_range) * 2 } else { 0 }
		wall_x := x1 + 2 + wall_offset

		hole_range := if height_for_hole / 2 > 1 { height_for_hole / 2 } else { 1 }
		hole_offset := if hole_range > 0 { helper.next_int(hole_range) * 2 } else { 0 }
		hole_y := y1 + 1 + hole_offset

		if wall_x > x2 || hole_y > y2 {
			return
		}

		for y in y1 .. y2 + 1 {
			if y != hole_y {
				m.set(wall_x, y, .wall)
			}
		}

		if wall_x > x1 + 1 {
			m.divide(x1, y1, wall_x - 1, y2)
		}
		if wall_x + 1 < x2 {
			m.divide(wall_x + 1, y1, x2, y2)
		}
	} else {

		wall_range := if height_for_wall / 2 > 1 { height_for_wall / 2 } else { 1 }
		wall_offset := if wall_range > 0 { helper.next_int(wall_range) * 2 } else { 0 }
		wall_y := y1 + 2 + wall_offset

		hole_range := if width_for_hole / 2 > 1 { width_for_hole / 2 } else { 1 }
		hole_offset := if hole_range > 0 { helper.next_int(hole_range) * 2 } else { 0 }
		hole_x := x1 + 1 + hole_offset

		if wall_y > y2 || hole_x > x2 {
			return
		}

		for x in x1 .. x2 + 1 {
			if x != hole_x {
				m.set(x, wall_y, .wall)
			}
		}

		if wall_y > y1 + 1 {
			m.divide(x1, y1, x2, wall_y - 1)
		}
		if wall_y + 1 < y2 {
			m.divide(x1, wall_y + 1, x2, y2)
		}
	}
}

fn (mut m Maze) generate() {
	if m.width < 5 || m.height < 5 {

		for x in 0 .. m.width {
			m.set(x, m.height / 2, .path)
		}
		return
	}

	m.divide(0, 0, m.width - 1, m.height - 1)
	m.add_random_paths()
}

fn (m Maze) to_bool_grid() [][]bool {
	mut result := [][]bool{len: m.height}

	for y in 0 .. m.height {
		mut bool_row := []bool{len: m.width}
		for x in 0 .. m.width {
			bool_row[x] = m.get(x, y) == .path
		}
		result[y] = bool_row
	}

	return result
}

fn (m Maze) is_connected(start []int, goal []int) bool {
	if start[0] >= m.width || start[1] >= m.height || goal[0] >= m.width || goal[1] >= m.height {
		return false
	}

	mut visited := [][]bool{len: m.height}
	for i in 0 .. m.height {
		visited[i] = []bool{len: m.width}
	}

	mut queue := [][]int{}
	visited[start[1]][start[0]] = true
	queue << start

	for queue.len > 0 {
		current := queue[0]
		queue.delete(0)
		x := current[0]
		y := current[1]

		if x == goal[0] && y == goal[1] {
			return true
		}

		if y > 0 && m.get(x, y - 1) == .path && !visited[y - 1][x] {
			visited[y - 1][x] = true
			queue << [x, y - 1]
		}

		if x + 1 < m.width && m.get(x + 1, y) == .path && !visited[y][x + 1] {
			visited[y][x + 1] = true
			queue << [x + 1, y]
		}

		if y + 1 < m.height && m.get(x, y + 1) == .path && !visited[y + 1][x] {
			visited[y + 1][x] = true
			queue << [x, y + 1]
		}

		if x > 0 && m.get(x - 1, y) == .path && !visited[y][x - 1] {
			visited[y][x - 1] = true
			queue << [x - 1, y]
		}
	}

	return false
}

pub fn generate_walkable_maze(width int, height int) [][]bool {
	mut maze := new_maze(width, height)
	maze.generate()

	start := [1, 1]
	goal := [width - 2, height - 2]

	if !maze.is_connected(start, goal) {

		for x in 0 .. width {
			for y in 0 .. height {
				if x < maze.width && y < maze.height {
					if x == 1 || y == 1 || x == width - 2 || y == height - 2 {
						maze.set(x, y, .path)
					}
				}
			}
		}
	}

	return maze.to_bool_grid()
}

pub struct MazeGenerator {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	bool_grid  [][]bool
}

pub fn new_mazegenerator() &benchmark.IBenchmark {
	mut bench := &MazeGenerator{
		BaseBenchmark: benchmark.new_base_benchmark('MazeGenerator')
		result_val:    0
		width:         0
		height:        0
	}
	return bench
}

pub fn (b MazeGenerator) name() string {
	return 'MazeGenerator'
}

fn grid_checksum(grid [][]bool) u32 {
	mut hasher := u32(2166136261) 
	prime := u32(16777619) 

	for y in 0 .. grid.len {
		row := grid[y]
		for x in 0 .. row.len {
			if row[x] { 
				j_squared := u32(x * x)
				hasher = (hasher ^ j_squared) * prime
			}
		}
	}
	return hasher
}

pub fn (mut b MazeGenerator) prepare() {
	b.width = int(helper.config_i64('MazeGenerator', 'w'))
	b.height = int(helper.config_i64('MazeGenerator', 'h'))
}

pub fn (mut b MazeGenerator) run(iteration_id int) {
	_ = iteration_id
	b.bool_grid = generate_walkable_maze(b.width, b.height)
}

pub fn (b MazeGenerator) checksum() u32 {
	return grid_checksum(b.bool_grid)
}