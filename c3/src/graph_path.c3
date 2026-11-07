module graph_path;

import benchmark;
import helper;
import std::io;
import std::collections::list;
import std::collections::priorityqueue;
import std::collections::pair;

alias IntPair = Pair{int, int};

struct AStarItem
{
	int priority;
	int vertex;
}

fn bool AStarItem.less(self, AStarItem other)
{
	return self.priority < other.priority;
}

alias AStarQueue = PriorityQueue{AStarItem};

struct GraphPathGraph
{
	int vertices;
	int jumps;
	int jump_len;
	List{int}* adj;
}

fn GraphPathGraph* graph_path_graph_new(int vertices, int jumps, int jump_len)
{
	GraphPathGraph* graph = mem::new(GraphPathGraph);
	graph.vertices = vertices;
	graph.jumps = jumps;
	graph.jump_len = jump_len;
	graph.adj = mem::new_array(List{int}, (usz)vertices);

	for (int i = 0; i < vertices; i++)
	{
		graph.adj[i].init(mem);
	}

	return graph;
}

fn void graph_path_graph_free(GraphPathGraph* graph)
{
	if (!graph) return;
	if (graph.adj)
	{
		for (int i = 0; i < graph.vertices; i++)
		{
			graph.adj[i].free();
		}
		free(graph.adj);
	}
	free(graph);
}

fn void graph_path_graph_add_edge(GraphPathGraph* graph, int u, int v)
{
	graph.adj[u].push(v);
	graph.adj[v].push(u);
}

fn void graph_path_graph_generate_random(GraphPathGraph* graph)
{
	for (int i = 1; i < graph.vertices; i++)
	{
		graph_path_graph_add_edge(graph, i, i - 1);
	}

	for (int v = 0; v < graph.vertices; v++)
	{
		int num_jumps = (int)helper::helper_next_int((uint)graph.jumps);
		for (int j = 0; j < num_jumps; j++)
		{
			int offset = (int)helper::helper_next_int((uint)graph.jump_len) - graph.jump_len / 2;
			int u      = v + offset;

			if (u >= 0 && u < graph.vertices && u != v)
			{
				graph_path_graph_add_edge(graph, v, u);
			}
		}
	}
}

struct GraphPathBaseData
{
	GraphPathGraph* graph;
	uint result_val;
}

fn void graph_path_base_prepare(Benchmark* self, String bench_name, GraphPathBaseData* data)
{
	int vertices = (int)helper::helper_config_i64(bench_name, "vertices");
	int jumps    = (int)helper::helper_config_i64(bench_name, "jumps");
	int jump_len = (int)helper::helper_config_i64(bench_name, "jump_len");

	data.graph = graph_path_graph_new(vertices, jumps, jump_len);
	graph_path_graph_generate_random(data.graph);
}

fn void graph_path_base_cleanup(GraphPathBaseData* data)
{
	graph_path_graph_free(data.graph);
	data.graph = null;
}

struct GraphPathBFSData
{
	GraphPathBaseData base;
}

fn int graph_path_bfs_search(GraphPathGraph* graph, int start, int target)
{
	if (start == target) return 0;

	char[] visited  = mem::new_array(char, (usz)graph.vertices);
	IntPair[] queue = mem::alloc_array(IntPair, (usz)graph.vertices);
	int front       = 0;
	int rear        = 0;

	visited[start] = 1;
	queue[rear++] = { start, 0 };

	while (front < rear)
	{
		IntPair current = queue[front++];
		int v           = current.first;
		int dist        = current.second;

		for (int i = 0; i < graph.adj[v].len(); i++)
		{
			int neighbor = graph.adj[v][i];
			if (neighbor == target)
			{
				free(visited);
				free(queue);
				return dist + 1;
			}

			if (!visited[neighbor])
			{
				visited[neighbor] = 1;
				queue[rear++] = { neighbor, dist + 1 };
			}
		}
	}

	free(visited);
	free(queue);
	return -1;
}

fn void graph_path_bfs_prepare(Benchmark* self)
{
	GraphPathBFSData* data = (GraphPathBFSData*)self.data;
	graph_path_base_prepare(self, "Graph::BFS", &data.base);
}

fn void graph_path_bfs_run(Benchmark* self, int iteration_id)
{
	GraphPathBFSData* data = (GraphPathBFSData*)self.data;
	int length             = graph_path_bfs_search(data.base.graph, 0, data.base.graph.vertices - 1);
	data.base.result_val += (uint)length;
}

fn uint graph_path_bfs_checksum(Benchmark* self)
{
	return ((GraphPathBFSData*)self.data).base.result_val;
}

fn void graph_path_bfs_cleanup(Benchmark* self)
{
	graph_path_base_cleanup(&((GraphPathBFSData*)self.data).base);
}

fn Benchmark* graph_path_bfs_create() @cname("GraphPathBFS_create") @export
{
	Benchmark* bench       = benchmark::benchmark_create("Graph::BFS");
	GraphPathBFSData* data = mem::new(GraphPathBFSData);

	bench.data = data;
	bench.prepare = (PrepareFn)&graph_path_bfs_prepare;
	bench.run = (RunFn)&graph_path_bfs_run;
	bench.checksum = (ChecksumFn)&graph_path_bfs_checksum;
	bench.cleanup = (CleanupFn)&graph_path_bfs_cleanup;

	return bench;
}

struct GraphPathDFSData
{
	GraphPathBaseData base;
}

fn int graph_path_dfs_search(GraphPathGraph* graph, int start, int target)
{
	if (start == target) return 0;

	char[] visited = mem::new_array(char, (usz)graph.vertices);
	List{IntPair} stack;
	stack.init(mem);
	defer stack.free();

	int best_path = int::max;

	stack.push({ start, 0 });

	while (!stack.is_empty())
	{
		IntPair current = stack.pop()!!;
		int v           = current.first;
		int dist        = current.second;

		if (visited[v] || dist >= best_path) continue;
		visited[v] = 1;

		for (int i = 0; i < graph.adj[v].len(); i++)
		{
			int neighbor = graph.adj[v][i];
			if (neighbor == target)
			{
				if (dist + 1 < best_path)
				{
					best_path = dist + 1;
				}
			}
			else if (!visited[neighbor])
			{
				stack.push({ neighbor, dist + 1 });
			}
		}
	}

	free(visited);
	return best_path == int::max ? -1 : best_path;
}

fn void graph_path_dfs_prepare(Benchmark* self)
{
	GraphPathDFSData* data = (GraphPathDFSData*)self.data;
	graph_path_base_prepare(self, "Graph::DFS", &data.base);
}

fn void graph_path_dfs_run(Benchmark* self, int iteration_id)
{
	GraphPathDFSData* data = (GraphPathDFSData*)self.data;
	int length             = graph_path_dfs_search(data.base.graph, 0, data.base.graph.vertices - 1);
	data.base.result_val += (uint)length;
}

fn uint graph_path_dfs_checksum(Benchmark* self)
{
	return ((GraphPathDFSData*)self.data).base.result_val;
}

fn void graph_path_dfs_cleanup(Benchmark* self)
{
	graph_path_base_cleanup(&((GraphPathDFSData*)self.data).base);
}

fn Benchmark* graph_path_dfs_create() @cname("GraphPathDFS_create") @export
{
	Benchmark* bench       = benchmark::benchmark_create("Graph::DFS");
	GraphPathDFSData* data = mem::new(GraphPathDFSData);

	bench.data = data;
	bench.prepare = (PrepareFn)&graph_path_dfs_prepare;
	bench.run = (RunFn)&graph_path_dfs_run;
	bench.checksum = (ChecksumFn)&graph_path_dfs_checksum;
	bench.cleanup = (CleanupFn)&graph_path_dfs_cleanup;

	return bench;
}

struct GraphPathAStarData
{
	GraphPathBaseData base;
}

fn int heuristic(int v, int target)
{
	return target - v;
}

fn int graph_path_astar_search(GraphPathGraph* graph, int start, int target)
{
	if (start == target) return 0;

	int n = graph.vertices;

	int[] g_score = mem::alloc_array(int, (usz)n);
	int[] best_f  = mem::alloc_array(int, (usz)n);

	for (int i = 0; i < n; i++)
	{
		g_score[i] = int::max;
		best_f[i] = int::max;
	}

	g_score[start] = 0;
	int f_start = heuristic(start, target);
	best_f[start] = f_start;

	AStarQueue open_set;
	open_set.init(mem, 16);
	defer open_set.free();

	open_set.push({ f_start, start });

	while (!open_set.is_empty())
	{
		AStarItem current_item = open_set.pop()!!;
		int current            = current_item.vertex;

		if (current == target)
		{
			int result = g_score[current];
			free(g_score);
			free(best_f);
			return result;
		}

		for (int i = 0; i < graph.adj[current].len(); i++)
		{
			int neighbor    = graph.adj[current][i];
			int tentative_g = g_score[current] + 1;

			if (tentative_g < g_score[neighbor])
			{
				g_score[neighbor] = tentative_g;
				int f_new = tentative_g + heuristic(neighbor, target);

				if (f_new < best_f[neighbor])
				{
					best_f[neighbor] = f_new;
					open_set.push({ f_new, neighbor });
				}
			}
		}
	}

	free(g_score);
	free(best_f);
	return -1;
}

fn void graph_path_astar_prepare(Benchmark* self)
{
	GraphPathAStarData* data = (GraphPathAStarData*)self.data;
	graph_path_base_prepare(self, "Graph::AStar", &data.base);
}

fn void graph_path_astar_run(Benchmark* self, int iteration_id)
{
	GraphPathAStarData* data = (GraphPathAStarData*)self.data;
	int length               = graph_path_astar_search(data.base.graph, 0, data.base.graph.vertices - 1);
	data.base.result_val += (uint)length;
}

fn uint graph_path_astar_checksum(Benchmark* self)
{
	return ((GraphPathAStarData*)self.data).base.result_val;
}

fn void graph_path_astar_cleanup(Benchmark* self)
{
	graph_path_base_cleanup(&((GraphPathAStarData*)self.data).base);
}

fn Benchmark* graph_path_astar_create() @cname("GraphPathAStar_create") @export
{
	Benchmark* bench         = benchmark::benchmark_create("Graph::AStar");
	GraphPathAStarData* data = mem::new(GraphPathAStarData);

	bench.data = data;
	bench.prepare = (PrepareFn)&graph_path_astar_prepare;
	bench.run = (RunFn)&graph_path_astar_run;
	bench.checksum = (ChecksumFn)&graph_path_astar_checksum;
	bench.cleanup = (CleanupFn)&graph_path_astar_cleanup;

	return bench;
}