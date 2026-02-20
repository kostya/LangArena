module graph_paths

import benchmark
import helper

struct Graph {
pub:
	vertices int
	jumps    int
	jump_len int
pub mut:
	adj [][]int
}

pub fn graph_new(vertices int, jumps int, jump_len int) &Graph {
	mut adj := [][]int{len: vertices}
	return &Graph{
		vertices: vertices
		jumps:    jumps
		jump_len: jump_len
		adj:      adj
	}
}

pub fn (mut graph Graph) add_edge(u int, v int) {
	graph.adj[u] << v
	graph.adj[v] << u
}

pub fn (mut graph Graph) generate_random() {
	for i in 1 .. graph.vertices {
		graph.add_edge(i, i - 1)
	}

	for v in 0 .. graph.vertices {
		num_jumps := helper.next_int(graph.jumps)
		for _ in 0 .. num_jumps {
			offset := helper.next_int(graph.jump_len) - graph.jump_len / 2
			u := v + offset

			if u >= 0 && u < graph.vertices && u != v {
				graph.add_edge(v, u)
			}
		}
	}
}

struct Pair {
	a int
	b int
}

struct GraphPathBenchmark {
	benchmark.BaseBenchmark
pub mut:
	graph &Graph = unsafe { nil }
mut:
	result_val u32
}

fn new_graph_path_benchmark(class_name string) GraphPathBenchmark {
	return GraphPathBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark(class_name)
		result_val:    0
	}
}

pub struct GraphPathBFS {
	GraphPathBenchmark
}

pub fn new_graphpathbfs() &benchmark.IBenchmark {
	mut bench := &GraphPathBFS{
		GraphPathBenchmark: new_graph_path_benchmark('GraphPathBFS')
	}
	return bench
}

pub fn (b GraphPathBFS) name() string {
	return 'GraphPathBFS'
}

fn bfs_shortest_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	mut visited := []u8{len: graph.vertices, init: 0}
	mut queue := []Pair{}
	mut head := 0

	visited[start] = 1
	queue << Pair{start, 0}

	for head < queue.len {
		current := queue[head]
		head++
		v := current.a
		dist := current.b

		for neighbor in graph.adj[v] {
			if neighbor == target {
				return dist + 1
			}

			if visited[neighbor] == 0 {
				visited[neighbor] = 1
				queue << Pair{neighbor, dist + 1}
			}
		}
	}

	return -1
}

pub fn (mut b GraphPathBFS) prepare() {
	vertices := int(helper.config_i64('GraphPathBFS', 'vertices'))
	jumps := int(helper.config_i64('GraphPathBFS', 'jumps'))
	jump_len := int(helper.config_i64('GraphPathBFS', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathBFS) run(iteration_id int) {
	length := bfs_shortest_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathBFS) checksum() u32 {
	return b.result_val
}

pub struct GraphPathDFS {
	GraphPathBenchmark
}

pub fn new_graphpathdfs() &benchmark.IBenchmark {
	mut bench := &GraphPathDFS{
		GraphPathBenchmark: new_graph_path_benchmark('GraphPathDFS')
	}
	return bench
}

pub fn (b GraphPathDFS) name() string {
	return 'GraphPathDFS'
}

fn dfs_find_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	mut visited := []u8{len: graph.vertices, init: 0}
	mut stack := []Pair{}
	mut best_path := int(0x7fffffff)

	stack << Pair{start, 0}

	for stack.len > 0 {
		current := stack[stack.len - 1]
		stack.delete_last()
		v := current.a
		dist := current.b

		if visited[v] == 1 || dist >= best_path {
			continue
		}
		visited[v] = 1

		for neighbor in graph.adj[v] {
			if neighbor == target {
				if dist + 1 < best_path {
					best_path = dist + 1
				}
			} else if visited[neighbor] == 0 {
				stack << Pair{neighbor, dist + 1}
			}
		}
	}

	return if best_path == int(0x7fffffff) { -1 } else { best_path }
}

pub fn (mut b GraphPathDFS) prepare() {
	vertices := int(helper.config_i64('GraphPathDFS', 'vertices'))
	jumps := int(helper.config_i64('GraphPathDFS', 'jumps'))
	jump_len := int(helper.config_i64('GraphPathDFS', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathDFS) run(iteration_id int) {
	length := dfs_find_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathDFS) checksum() u32 {
	return b.result_val
}

struct PriorityQueue {
mut:
	vertices   []int
	priorities []int
	size       int
}

fn priority_queue_new(capacity int) PriorityQueue {
	return PriorityQueue{
		vertices:   []int{len: capacity, init: 0}
		priorities: []int{len: capacity, init: 0}
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

pub struct GraphPathAStar {
	GraphPathBenchmark
}

pub fn new_graphpathastar() &benchmark.IBenchmark {
	mut bench := &GraphPathAStar{
		GraphPathBenchmark: new_graph_path_benchmark('GraphPathAStar')
	}
	return bench
}

pub fn (b GraphPathAStar) name() string {
	return 'GraphPathAStar'
}

fn heuristic(v int, target int) int {
	return target - v
}

fn a_star_shortest_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	mut g_score := []int{len: graph.vertices, init: int(0x7fffffff)}
	mut closed := []u8{len: graph.vertices, init: 0}

	g_score[start] = 0

	mut open_set := priority_queue_new(graph.vertices)
	mut in_open_set := []u8{len: graph.vertices, init: 0}

	open_set.push(start, heuristic(start, target))
	in_open_set[start] = 1

	for {
		current := open_set.pop() or { break }
		in_open_set[current] = 0

		if current == target {
			return g_score[current]
		}

		closed[current] = 1

		for neighbor in graph.adj[current] {
			if closed[neighbor] == 1 {
				continue
			}

			tentative_g := g_score[current] + 1

			if tentative_g < g_score[neighbor] {
				g_score[neighbor] = tentative_g
				f := tentative_g + heuristic(neighbor, target)

				if in_open_set[neighbor] == 0 {
					open_set.push(neighbor, f)
					in_open_set[neighbor] = 1
				}
			}
		}
	}

	return -1
}

pub fn (mut b GraphPathAStar) prepare() {
	vertices := int(helper.config_i64('GraphPathAStar', 'vertices'))
	jumps := int(helper.config_i64('GraphPathAStar', 'jumps'))
	jump_len := int(helper.config_i64('GraphPathAStar', 'jump_len'))

	b.graph = graph_new(vertices, jumps, jump_len)
	b.graph.generate_random()
}

pub fn (mut b GraphPathAStar) run(iteration_id int) {
	length := a_star_shortest_path(b.graph, 0, b.graph.vertices - 1)
	b.result_val += u32(length)
}

pub fn (b GraphPathAStar) checksum() u32 {
	return b.result_val
}
