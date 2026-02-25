module mazebench

import benchmark
import helper
import math

enum CellKind {
	wall   = 0
	space  = 1
	start  = 2
	finish = 3
	border = 4
	path   = 5
}

fn is_walkable(kind CellKind) bool {
	return kind == .space || kind == .start || kind == .finish
}

@[heap]
struct Cell {
mut:
	kind      CellKind
	neighbors []&Cell
	x         int
	y         int
}

fn new_cell(x int, y int) &Cell {
	return &Cell{
		kind:      .wall
		neighbors: []&Cell{}
		x:         x
		y:         y
	}
}

fn (mut c Cell) reset() {
	if c.kind == .space {
		c.kind = .wall
	}
}

struct Maze {
pub:
	width  int
	height int
mut:
	cells  [][]&Cell
	start  &Cell
	finish &Cell
}

fn new_maze(width int, height int) &Maze {
	actual_width := if width > 5 { width } else { 5 }
	actual_height := if height > 5 { height } else { 5 }

	mut cells := [][]&Cell{}
	for y in 0 .. actual_height {
		mut row := []&Cell{}
		for x in 0 .. actual_width {
			row << new_cell(x, y)
		}
		cells << row
	}

	mut maze := &Maze{
		width:  actual_width
		height: actual_height
		cells:  cells
		start:  cells[1][1]
		finish: cells[actual_height - 2][actual_width - 2]
	}

	maze.start.kind = .start
	maze.finish.kind = .finish
	maze.update_neighbors()

	return maze
}

fn (mut m Maze) update_neighbors() {
	for y in 0 .. m.height {
		for x in 0 .. m.width {
			mut cell := m.cells[y][x]
			cell.neighbors = []&Cell{}

			if x > 0 && y > 0 && x < m.width - 1 && y < m.height - 1 {
				cell.neighbors << m.cells[y - 1][x]
				cell.neighbors << m.cells[y + 1][x]
				cell.neighbors << m.cells[y][x + 1]
				cell.neighbors << m.cells[y][x - 1]

				for _ in 0 .. 4 {
					i := helper.next_int(4)
					j := helper.next_int(4)
					if i != j {
						temp := cell.neighbors[i]
						cell.neighbors[i] = cell.neighbors[j]
						cell.neighbors[j] = temp
					}
				}
			} else {
				cell.kind = .border
			}
		}
	}
}

fn (mut m Maze) reset() {
	for y in 0 .. m.height {
		for x in 0 .. m.width {
			mut cell := m.cells[y][x]
			cell.reset()
		}
	}
	m.start.kind = .start
	m.finish.kind = .finish
}

fn (mut m Maze) dig(start_cell &Cell) {
	mut stack := []&Cell{}
	stack << start_cell

	for stack.len > 0 {
		mut cell := stack.pop()

		mut walkable := 0
		for neighbor in cell.neighbors {
			if is_walkable(neighbor.kind) {
				walkable++
			}
		}

		if walkable != 1 {
			continue
		}

		cell.kind = .space
		for neighbor in cell.neighbors {
			if neighbor.kind == .wall {
				stack << neighbor
			}
		}
	}
}

fn (mut m Maze) ensure_open_finish(start_cell &Cell) {
	mut stack := []&Cell{}
	stack << start_cell
	mut stack_ptr := 1

	for stack_ptr > 0 {
		stack_ptr--
		mut cell := stack[stack_ptr]

		cell.kind = .space

		mut walkable := 0
		for i in 0 .. cell.neighbors.len {
			if is_walkable(cell.neighbors[i].kind) {
				walkable++
			}
		}

		if walkable > 1 {
			continue
		}

		for i in 0 .. cell.neighbors.len {
			if cell.neighbors[i].kind == .wall {
				if stack.len <= stack_ptr {
					stack << cell.neighbors[i]
				} else {
					stack[stack_ptr] = cell.neighbors[i]
				}
				stack_ptr++
			}
		}
	}
}

fn (mut m Maze) generate() {
	for n in m.start.neighbors {
		if n.kind == .wall {
			m.dig(n)
		}
	}

	for n in m.finish.neighbors {
		if n.kind == .wall {
			m.ensure_open_finish(n)
		}
	}
}

fn (m Maze) middle_cell() &Cell {
	return m.cells[m.height / 2][m.width / 2]
}

fn (m Maze) checksum() u32 {
	mut hasher := u32(2166136261)
	prime := u32(16777619)

	for y in 0 .. m.height {
		for x in 0 .. m.width {
			if m.cells[y][x].kind == .space {
				val := u32(x * y)
				hasher = (hasher ^ val) * prime
			}
		}
	}
	return hasher
}

@[heap]
pub struct MazeGenerator {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	maze       &Maze
}

pub fn new_maze_generator() &benchmark.IBenchmark {
	mut bench := &MazeGenerator{
		BaseBenchmark: benchmark.new_base_benchmark('Maze::Generator')
		result_val:    0
		width:         0
		height:        0
		maze:          unsafe { nil }
	}
	return bench
}

pub fn (b MazeGenerator) name() string {
	return 'Maze::Generator'
}

pub fn (mut b MazeGenerator) prepare() {
	b.width = int(helper.config_i64('Maze::Generator', 'w'))
	b.height = int(helper.config_i64('Maze::Generator', 'h'))
	b.maze = new_maze(b.width, b.height)
	b.result_val = 0
}

pub fn (mut b MazeGenerator) run(iteration_id int) {
	b.maze.reset()
	b.maze.generate()
	b.result_val += u32(b.maze.middle_cell().kind)
}

pub fn (b MazeGenerator) checksum() u32 {
	return b.result_val + b.maze.checksum()
}

@[heap]
struct PathNode {
	cell   &Cell
	parent int
}

@[heap]
pub struct MazeBFS {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	maze       &Maze
	path       []&Cell
}

pub fn new_maze_bfs() &benchmark.IBenchmark {
	mut bench := &MazeBFS{
		BaseBenchmark: benchmark.new_base_benchmark('Maze::BFS')
		result_val:    0
		width:         0
		height:        0
		maze:          unsafe { nil }
		path:          []&Cell{}
	}
	return bench
}

pub fn (b MazeBFS) name() string {
	return 'Maze::BFS'
}

pub fn (mut b MazeBFS) prepare() {
	b.width = int(helper.config_i64('Maze::BFS', 'w'))
	b.height = int(helper.config_i64('Maze::BFS', 'h'))
	b.maze = new_maze(b.width, b.height)
	b.maze.generate()
	b.result_val = 0
	b.path = []&Cell{}
}

fn (mut b MazeBFS) bfs(start &Cell, target &Cell) []&Cell {
	if start == target {
		return [start]
	}

	mut visited := [][]bool{len: b.height}
	for i in 0 .. b.height {
		visited[i] = []bool{len: b.width, init: false}
	}

	mut queue := []PathNode{}
	mut head := 0

	visited[start.y][start.x] = true
	queue << PathNode{start, -1}

	for head < queue.len {
		path_id := head
		node := queue[head]
		head++

		for neighbor in node.cell.neighbors {
			if neighbor == target {
				mut result := [target]
				mut cur := path_id
				for cur >= 0 {
					result << queue[cur].cell
					cur = queue[cur].parent
				}
				result.reverse_in_place()
				return result
			}

			if is_walkable(neighbor.kind) && !visited[neighbor.y][neighbor.x] {
				visited[neighbor.y][neighbor.x] = true
				queue << PathNode{neighbor, path_id}  // parent = path_id!
			}
		}
	}

	return []&Cell{}
}

fn (b MazeBFS) mid_cell_checksum(path []&Cell) u32 {
	if path.len == 0 {
		return 0
	}
	cell := path[path.len / 2]
	return u32(cell.x * cell.y)
}

pub fn (mut b MazeBFS) run(iteration_id int) {
	b.path = b.bfs(b.maze.start, b.maze.finish)
	b.result_val += u32(b.path.len)
}

pub fn (b MazeBFS) checksum() u32 {
	return b.result_val + b.mid_cell_checksum(b.path)
}

struct PriorityQueue {
mut:
	vertices   []int
	priorities []int
	size       int
}

fn priority_queue_new(capacity int) PriorityQueue {
	return PriorityQueue{
		vertices:   []int{len: capacity}
		priorities: []int{len: capacity}
		size:       0
	}
}

fn (mut pq PriorityQueue) push(vertex int, priority int) {
	if pq.size >= pq.vertices.len {
		pq.vertices << 0
		pq.priorities << 0
	}

	mut i := pq.size
	pq.size++
	pq.vertices[i] = vertex
	pq.priorities[i] = priority

	for i > 0 {
		parent := (i - 1) / 2
		if pq.priorities[parent] <= pq.priorities[i] {
			break
		}
		pq.vertices[i], pq.vertices[parent] = pq.vertices[parent], pq.vertices[i]
		pq.priorities[i], pq.priorities[parent] = pq.priorities[parent], pq.priorities[i]
		i = parent
	}
}

fn (mut pq PriorityQueue) pop() ?int {
	if pq.size == 0 {
		return none
	}

	result := pq.vertices[0]
	pq.size--

	if pq.size > 0 {
		pq.vertices[0] = pq.vertices[pq.size]
		pq.priorities[0] = pq.priorities[pq.size]

		mut i := 0
		for {
			left := 2 * i + 1
			right := 2 * i + 2
			mut smallest := i

			if left < pq.size && pq.priorities[left] < pq.priorities[smallest] {
				smallest = left
			}
			if right < pq.size && pq.priorities[right] < pq.priorities[smallest] {
				smallest = right
			}
			if smallest == i {
				break
			}
			pq.vertices[i], pq.vertices[smallest] = pq.vertices[smallest], pq.vertices[i]
			pq.priorities[i], pq.priorities[smallest] = pq.priorities[smallest], pq.priorities[i]
			i = smallest
		}
	}

	return result
}

@[heap]
pub struct MazeAStar {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	maze       &Maze
	path       []&Cell
}

pub fn new_maze_astar() &benchmark.IBenchmark {
	mut bench := &MazeAStar{
		BaseBenchmark: benchmark.new_base_benchmark('Maze::AStar')
		result_val:    0
		width:         0
		height:        0
		maze:          unsafe { nil }
		path:          []&Cell{}
	}
	return bench
}

pub fn (b MazeAStar) name() string {
	return 'Maze::AStar'
}

pub fn (mut b MazeAStar) prepare() {
	b.width = int(helper.config_i64('Maze::AStar', 'w'))
	b.height = int(helper.config_i64('Maze::AStar', 'h'))
	b.maze = new_maze(b.width, b.height)
	b.maze.generate()
	b.result_val = 0
	b.path = []&Cell{}
}

fn (b MazeAStar) heuristic(a &Cell, c &Cell) int {
	return math.abs(a.x - c.x) + math.abs(a.y - c.y)
}

fn (b MazeAStar) idx(y int, x int) int {
	return y * b.width + x
}

fn (mut b MazeAStar) astar(start &Cell, target &Cell) []&Cell {
	if start == target {
		return [start]
	}

	size := b.width * b.height

	mut came_from := []int{len: size, init: -1}
	mut g_score := []int{len: size, init: 2147483647}
	mut best_f := []int{len: size, init: 2147483647}

	start_idx := b.idx(start.y, start.x)
	target_idx := b.idx(target.y, target.x)

	mut open_set := priority_queue_new(size)
	mut in_open := []u8{len: size, init: 0}

	g_score[start_idx] = 0
	f_start := b.heuristic(start, target)
	open_set.push(start_idx, f_start)
	best_f[start_idx] = f_start
	in_open[start_idx] = 1

	for open_set.size > 0 {
		current_idx := open_set.pop() or { break }

		if current_idx == target_idx {
			mut result := []&Cell{}
			mut cur := current_idx
			for cur != -1 {
				y := cur / b.width
				x := cur % b.width
				result << b.maze.cells[y][x]
				cur = came_from[cur]
			}
			result.reverse_in_place()
			return result
		}

		current_y := current_idx / b.width
		current_x := current_idx % b.width
		current_cell := b.maze.cells[current_y][current_x]
		current_g := g_score[current_idx]

		for neighbor in current_cell.neighbors {
			if !is_walkable(neighbor.kind) {
				continue
			}

			neighbor_idx := b.idx(neighbor.y, neighbor.x)
			tentative_g := current_g + 1

			if tentative_g < g_score[neighbor_idx] {
				came_from[neighbor_idx] = current_idx
				g_score[neighbor_idx] = tentative_g
				f_new := tentative_g + b.heuristic(neighbor, target)

				if f_new < best_f[neighbor_idx] {
					best_f[neighbor_idx] = f_new
					if in_open[neighbor_idx] == 0 {
						open_set.push(neighbor_idx, f_new)
						in_open[neighbor_idx] = 1
					}
				}
			}
		}
	}

	return []&Cell{}
}

fn (b MazeAStar) mid_cell_checksum(path []&Cell) u32 {
	if path.len == 0 {
		return 0
	}
	cell := path[path.len / 2]
	return u32(cell.x * cell.y)
}

pub fn (mut b MazeAStar) run(iteration_id int) {
	b.path = b.astar(b.maze.start, b.maze.finish)
	b.result_val += u32(b.path.len)
}

pub fn (b MazeAStar) checksum() u32 {
	return b.result_val + b.mid_cell_checksum(b.path)
}
