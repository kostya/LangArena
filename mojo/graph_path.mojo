from helper import Helper
from benchmark import Benchmark, Config


struct _Graph:
    var vertices: Int
    var adj: List[List[Int]]

    def __init__(out self, vertices: Int):
        self.vertices = vertices
        self.adj = List[List[Int]]()
        for _ in range(vertices):
            self.adj.append(List[Int]())

    def add_edge(mut self, u: Int, v: Int):
        self.adj[u].append(v)
        self.adj[v].append(u)

    def generate_random(
        mut self, mut helper: Helper, jumps: Int, jump_len: Int
    ):
        for i in range(1, self.vertices):
            self.add_edge(i, i - 1)

        for v in range(self.vertices):
            var times = helper.next_int(jumps)
            for _ in range(times):
                var offset = helper.next_int(jump_len) - jump_len // 2
                var u = v + offset
                if u >= 0 and u < self.vertices and u != v:
                    self.add_edge(v, u)


struct AStarEntry(Comparable, Copyable):
    var priority: Int
    var vertex: Int

    def __init__(out self, priority: Int, vertex: Int):
        self.priority = priority
        self.vertex = vertex

    def __lt__(self, other: Self) -> Bool:
        if self.priority != other.priority:
            return self.priority > other.priority
        return self.vertex > other.vertex

    def __eq__(self, other: Self) -> Bool:
        return self.priority == other.priority and self.vertex == other.vertex


struct GraphBFS(Benchmark):
    var graph: _Graph
    var result: UInt32
    var jumps: Int
    var jump_len: Int

    def __init__(out self, config: Config) raises:
        var vertices = config.get_i64("Graph::BFS", "vertices")
        self.jumps = config.get_i64("Graph::BFS", "jumps")
        self.jump_len = config.get_i64("Graph::BFS", "jump_len")
        self.graph = _Graph(vertices)
        self.result = 0

    def class_name(self) -> String:
        return "Graph::BFS"

    def prepare(mut self, mut helper: Helper) raises:
        self.graph.generate_random(helper, self.jumps, self.jump_len)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var length = Self.bfs_shortest_path(
            self.graph, 0, self.graph.vertices - 1
        )
        self.result += UInt32(length)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def bfs_shortest_path(graph: _Graph, start: Int, target: Int) -> Int:
        if start == target:
            return 0

        var visited = List[Bool](length=graph.vertices, fill=False)
        var queue = List[Tuple[Int, Int]](capacity=graph.vertices)
        queue.append((start, 0))
        visited[start] = True

        var q_idx = 0
        while q_idx < len(queue):
            var cur = queue[q_idx]
            q_idx += 1
            var v = cur[0]
            var dist = cur[1]

            for neighbor in graph.adj[v]:
                if neighbor == target:
                    return dist + 1
                if not visited[neighbor]:
                    visited[neighbor] = True
                    queue.append((neighbor, dist + 1))

        return -1


struct GraphDFS(Benchmark):
    var graph: _Graph
    var result: UInt32
    var jumps: Int
    var jump_len: Int

    def __init__(out self, config: Config) raises:
        var vertices = config.get_i64("Graph::DFS", "vertices")
        self.jumps = config.get_i64("Graph::DFS", "jumps")
        self.jump_len = config.get_i64("Graph::DFS", "jump_len")
        self.graph = _Graph(vertices)
        self.result = 0

    def class_name(self) -> String:
        return "Graph::DFS"

    def prepare(mut self, mut helper: Helper) raises:
        self.graph.generate_random(helper, self.jumps, self.jump_len)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var length = Self.dfs_shortest_path(
            self.graph, 0, self.graph.vertices - 1
        )
        self.result += UInt32(length)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def dfs_shortest_path(graph: _Graph, start: Int, target: Int) -> Int:
        if start == target:
            return 0

        var visited = List[Bool](length=graph.vertices, fill=False)
        var stack: List[Tuple[Int, Int]] = [(start, 0)]
        var best_path = 2147483647

        while len(stack) > 0:
            var cur = stack.pop()
            var v = cur[0]
            var dist = cur[1]

            if visited[v] or dist >= best_path:
                continue
            visited[v] = True

            for neighbor in graph.adj[v]:
                if neighbor == target:
                    if dist + 1 < best_path:
                        best_path = dist + 1
                elif not visited[neighbor]:
                    stack.append((neighbor, dist + 1))

        if best_path == 2147483647:
            return -1
        return best_path


struct GraphAStar(Benchmark):
    var graph: _Graph
    var result: UInt32
    var jumps: Int
    var jump_len: Int

    def __init__(out self, config: Config) raises:
        var vertices = config.get_i64("Graph::AStar", "vertices")
        self.jumps = config.get_i64("Graph::AStar", "jumps")
        self.jump_len = config.get_i64("Graph::AStar", "jump_len")
        self.graph = _Graph(vertices)
        self.result = 0

    def class_name(self) -> String:
        return "Graph::AStar"

    def prepare(mut self, mut helper: Helper) raises:
        self.graph.generate_random(helper, self.jumps, self.jump_len)

    def run(mut self, iteration_id: Int, mut helper: Helper) raises:
        var length = Self.astar_shortest_path(
            self.graph, 0, self.graph.vertices - 1
        )
        self.result += UInt32(length)

    def checksum(mut self) -> UInt32:
        return self.result

    @staticmethod
    def astar_shortest_path(graph: _Graph, start: Int, target: Int) -> Int:
        if start == target:
            return 0

        var n = graph.vertices
        var INF = 2147483647

        var g_score = List[Int](length=n, fill=INF)
        var best_f = List[Int](length=n, fill=INF)

        g_score[start] = 0
        var f_start = target - start
        best_f[start] = f_start

        from std.collections import BinaryHeap

        var open_set = BinaryHeap[AStarEntry]()
        open_set.push(AStarEntry(f_start, start))

        while len(open_set) > 0:
            var entry = open_set.pop()
            var current = entry.vertex

            if current == target:
                return g_score[current]

            for neighbor in graph.adj[current]:
                var tentative_g = g_score[current] + 1

                if tentative_g < g_score[neighbor]:
                    g_score[neighbor] = tentative_g
                    var f_new = tentative_g + (target - neighbor)

                    if f_new < best_f[neighbor]:
                        best_f[neighbor] = f_new
                        open_set.push(AStarEntry(f_new, neighbor))

        return -1
