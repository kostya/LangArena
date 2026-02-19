module astar_pathfinder

import benchmark
import maze_generator
import helper

@[heap]
struct FastNode {
	x       int
	y       int
	f_score int
}

@[inline]
fn fast_node_compare(a &FastNode, b &FastNode) int {
	if a.f_score != b.f_score {
		return a.f_score - b.f_score
	}
	if a.y != b.y {
		return a.y - b.y
	}
	return a.x - b.x
}

struct FastBinaryHeap {
mut:
	nodes []FastNode
	size  int
}

fn new_fast_binary_heap(initial_capacity int) FastBinaryHeap {
	return FastBinaryHeap{
		nodes: []FastNode{cap: initial_capacity + 10}
		size:  0
	}
}

@[inline]
fn (heap &FastBinaryHeap) len() int {
	return heap.size
}

@[inline]
fn (heap &FastBinaryHeap) is_empty() bool {
	return heap.size == 0
}

fn (mut heap FastBinaryHeap) push(item FastNode) {
	if heap.size >= heap.nodes.len {
		heap.nodes << item
	} else {
		heap.nodes[heap.size] = item
	}

	mut i := heap.size
	heap.size++

	for i > 0 {
		parent := (i - 1) >> 1
		if fast_node_compare(&heap.nodes[i], &heap.nodes[parent]) >= 0 {
			break
		}

		temp := heap.nodes[i]
		heap.nodes[i] = heap.nodes[parent]
		heap.nodes[parent] = temp
		i = parent
	}
}

fn (mut heap FastBinaryHeap) pop() ?FastNode {
	if heap.size == 0 {
		return none
	}

	result := heap.nodes[0]
	heap.size--

	if heap.size > 0 {
		heap.nodes[0] = heap.nodes[heap.size]

		mut i := 0
		for {
			left := (i << 1) + 1
			right := left + 1
			mut smallest := i

			if left < heap.size && fast_node_compare(&heap.nodes[left], &heap.nodes[smallest]) < 0 {
				smallest = left
			}
			if right < heap.size && fast_node_compare(&heap.nodes[right], &heap.nodes[smallest]) < 0 {
				smallest = right
			}

			if smallest == i {
				break
			}

			temp := heap.nodes[i]
			heap.nodes[i] = heap.nodes[smallest]
			heap.nodes[smallest] = temp
			i = smallest
		}
	}

	return result
}

struct AStarPathfinder {
	benchmark.BaseBenchmark
mut:
	result_val u32
	width      int
	height     int
	start_x    int
	start_y    int
	goal_x     int
	goal_y     int
	maze_grid  [][]bool
	g_scores   []int
	came_from  []int
	heap       FastBinaryHeap
}

const inf = 0x7fffffff
const straight_cost = 1000

pub fn new_astarpathfinder() &benchmark.IBenchmark {
	mut bench := &AStarPathfinder{
		BaseBenchmark: benchmark.new_base_benchmark('AStarPathfinder')
		result_val:    0
		width:         0
		height:        0
		start_x:       1
		start_y:       1
	}
	return bench
}

pub fn (b AStarPathfinder) name() string {
	return 'AStarPathfinder'
}

@[inline]
fn heuristic(x1 int, y1 int, x2 int, y2 int) int {
	dx := if x1 > x2 { x1 - x2 } else { x2 - x1 }
	dy := if y1 > y2 { y1 - y2 } else { y2 - y1 }
	return dx + dy
}

@[inline]
fn (b AStarPathfinder) pack_coords(x int, y int) int {
	return y * b.width + x
}

@[inline]
fn (b AStarPathfinder) unpack_coords(idx int) (int, int) {
	return idx % b.width, idx / b.width
}

fn (mut b AStarPathfinder) init_scores(size int) {
	b.g_scores = []int{len: size, init: inf}
	b.came_from = []int{len: size, init: -1}
}

fn (mut b AStarPathfinder) find_path() ([]int, int) {
	size := b.width * b.height
	start_idx := b.pack_coords(b.start_x, b.start_y)

	b.heap = new_fast_binary_heap(size)
	b.init_scores(size)

	b.g_scores[start_idx] = 0
	start_f := heuristic(b.start_x, b.start_y, b.goal_x, b.goal_y)
	b.heap.push(FastNode{b.start_x, b.start_y, start_f})

	mut nodes_explored := 0
	directions := [[0, -1], [1, 0], [0, 1], [-1, 0]]

	for !b.heap.is_empty() {
		current := b.heap.pop() or { break }
		nodes_explored++

		if current.x == b.goal_x && current.y == b.goal_y {
			mut path := []int{}
			mut x := current.x
			mut y := current.y

			for x != b.start_x || y != b.start_y {
				path << b.pack_coords(x, y)
				idx := b.pack_coords(x, y)
				prev_idx := b.came_from[idx]
				if prev_idx == -1 {
					break
				}
				x, y = b.unpack_coords(prev_idx)
			}

			path << b.pack_coords(b.start_x, b.start_y)

			mut reversed := []int{len: path.len}
			for i, val in path {
				reversed[path.len - 1 - i] = val
			}

			return reversed, nodes_explored
		}

		current_idx := b.pack_coords(current.x, current.y)
		current_g := b.g_scores[current_idx]

		for dir in directions {
			nx := current.x + dir[0]
			ny := current.y + dir[1]

			if nx < 0 || nx >= b.width || ny < 0 || ny >= b.height {
				continue
			}
			if !b.maze_grid[ny][nx] {
				continue
			}

			tentative_g := current_g + straight_cost
			neighbor_idx := b.pack_coords(nx, ny)

			if tentative_g < b.g_scores[neighbor_idx] {
				b.came_from[neighbor_idx] = current_idx
				b.g_scores[neighbor_idx] = tentative_g

				h := heuristic(nx, ny, b.goal_x, b.goal_y)
				f_score := tentative_g + h
				b.heap.push(FastNode{nx, ny, f_score})
			}
		}
	}

	return []int{}, nodes_explored
}

pub fn (mut b AStarPathfinder) prepare() {
	b.width = int(helper.config_i64('AStarPathfinder', 'w'))
	b.height = int(helper.config_i64('AStarPathfinder', 'h'))
	b.goal_x = b.width - 2
	b.goal_y = b.height - 2

	b.maze_grid = maze_generator.generate_walkable_maze(b.width, b.height)

	size := b.width * b.height
	b.g_scores = []int{len: size}
	b.came_from = []int{len: size}
}

pub fn (mut b AStarPathfinder) run(iteration_id int) {
	_ = iteration_id
	path, nodes_explored := b.find_path()

	mut local_result := u32(0)
	if path.len > 0 {
		local_result = (local_result << 5) + u32(path.len)
	}
	local_result = (local_result << 5) + u32(nodes_explored)

	b.result_val += local_result
}

pub fn (b AStarPathfinder) checksum() u32 {
	return b.result_val
}
