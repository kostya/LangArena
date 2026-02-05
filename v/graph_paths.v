module graph_paths

import benchmark
import helper

struct Graph {
pub:
	vertices   int
	components int
pub mut:
	adj [][]int
}

pub fn graph_new(vertices int, components int) &Graph {
	mut adj := [][]int{len: vertices}
	return &Graph{
		vertices:   vertices
		components: components
		adj:        adj
	}
}

pub fn (mut graph Graph) add_edge(u int, v int) {
	graph.adj[u] << v
	graph.adj[v] << u
}

pub fn (mut graph Graph) generate_random() {
	component_size := graph.vertices / graph.components

	for c in 0 .. graph.components {
		start_idx := c * component_size
		end_idx := if c == graph.components - 1 { graph.vertices } else { (c + 1) * component_size }

		for i in start_idx + 1 .. end_idx {
			parent := start_idx + helper.next_int(i - start_idx)
			graph.add_edge(i, parent)
		}

		extra_edges := component_size * 2
		for _ in 0 .. extra_edges {
			u := start_idx + helper.next_int(end_idx - start_idx)
			v := start_idx + helper.next_int(end_idx - start_idx)
			if u != v {
				graph.add_edge(u, v)
			}
		}
	}
}

pub fn (graph Graph) same_component(u int, v int) bool {
	component_size := graph.vertices / graph.components
	return (u / component_size) == (v / component_size)
}

struct Pair {
	a int
	b int
}

struct GraphPathBenchmark {
	benchmark.BaseBenchmark
pub mut:
	graph   &Graph = unsafe { nil }
	pairs   []Pair
	n_pairs i64
mut:
	result_val u32
}

fn new_graph_path_benchmark(class_name string) GraphPathBenchmark {
	return GraphPathBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark(class_name)
		n_pairs:       0
		result_val:    0
	}
}

fn generate_pairs(graph &Graph, n int) []Pair {
	mut result := []Pair{cap: n}
	component_size := graph.vertices / 10

	for _ in 0 .. n {
		if helper.next_int(100) < 70 {

			component := helper.next_int(10)
			start := component * component_size + helper.next_int(component_size)
			mut end := start
			for end == start {
				end = component * component_size + helper.next_int(component_size)
			}
			result << Pair{start, end}
		} else {

			c1 := helper.next_int(10)
			mut c2 := c1
			for c2 == c1 {
				c2 = helper.next_int(10)
			}
			start := c1 * component_size + helper.next_int(component_size)
			end := c2 * component_size + helper.next_int(component_size)
			result << Pair{start, end}
		}
	}
	return result
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
	b.n_pairs = int(helper.config_i64('GraphPathBFS', 'pairs'))
	mut vertices := int(helper.config_i64('GraphPathBFS', 'vertices'))
	comps := if vertices / 10000 > 10 { vertices / 10000 } else { 10 }
	b.graph = graph_new(vertices, comps)
	b.graph.generate_random()
	b.pairs = generate_pairs(b.graph, int(b.n_pairs))
}

pub fn (mut b GraphPathBFS) run(iteration_id int) {
	_ = iteration_id
	mut total_length := i64(0)

	for pair in b.pairs {
		length := bfs_shortest_path(b.graph, pair.a, pair.b)
		total_length += i64(length)
	}

	b.result_val += u32(total_length)
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
	b.n_pairs = int(helper.config_i64('GraphPathDFS', 'pairs'))
	mut vertices := int(helper.config_i64('GraphPathDFS', 'vertices'))

	comps := if vertices / 10000 > 10 { vertices / 10000 } else { 10 }
	b.graph = graph_new(vertices, comps)
	b.graph.generate_random()
	b.pairs = generate_pairs(b.graph, int(b.n_pairs))
}

pub fn (mut b GraphPathDFS) run(iteration_id int) {
	_ = iteration_id
	mut total_length := i64(0)

	for pair in b.pairs {
		length := dfs_find_path(b.graph, pair.a, pair.b)
		total_length += i64(length)
	}

	b.result_val += u32(total_length)
}

pub fn (b GraphPathDFS) checksum() u32 {
	return b.result_val
}

pub struct GraphPathDijkstra {
	GraphPathBenchmark
}

pub fn new_graphpathdijkstra() &benchmark.IBenchmark {
	mut bench := &GraphPathDijkstra{
		GraphPathBenchmark: new_graph_path_benchmark('GraphPathDijkstra')
	}
	return bench
}

pub fn (b GraphPathDijkstra) name() string {
	return 'GraphPathDijkstra'
}

fn dijkstra_shortest_path(graph &Graph, start int, target int) int {
	if start == target {
		return 0
	}

	inf := int(0x3fffffff) 
	mut dist := []int{len: graph.vertices, init: inf}
	mut visited := []u8{len: graph.vertices, init: 0}

	dist[start] = 0

	for _ in 0 .. graph.vertices {
		mut u := -1
		mut min_dist := inf

		for v in 0 .. graph.vertices {
			if visited[v] == 0 && dist[v] < min_dist {
				min_dist = dist[v]
				u = v
			}
		}

		if u == -1 || min_dist == inf || u == target {
			return if u == target { min_dist } else { -1 }
		}

		visited[u] = 1

		for v in graph.adj[u] {
			if dist[u] + 1 < dist[v] {
				dist[v] = dist[u] + 1
			}
		}
	}

	return -1
}

pub fn (mut b GraphPathDijkstra) prepare() {
	b.n_pairs = int(helper.config_i64('GraphPathDijkstra', 'pairs'))
	mut vertices := int(helper.config_i64('GraphPathDijkstra', 'vertices'))

	comps := if vertices / 10000 > 10 { vertices / 10000 } else { 10 }
	b.graph = graph_new(vertices, comps)
	b.graph.generate_random()
	b.pairs = generate_pairs(b.graph, int(b.n_pairs))
}

pub fn (mut b GraphPathDijkstra) run(iteration_id int) {
	_ = iteration_id
	mut total_length := i64(0)

	for pair in b.pairs {
		length := dijkstra_shortest_path(b.graph, pair.a, pair.b)
		total_length += i64(length)
	}

	b.result_val += u32(total_length)
}

pub fn (b GraphPathDijkstra) checksum() u32 {
	return b.result_val
}