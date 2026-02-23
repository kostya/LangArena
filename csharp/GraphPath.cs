public abstract class GraphPathBenchmark : Benchmark
{
    protected class Graph
    {
        public int Vertices { get; }
        public int Jumps { get; }
        public int JumpLen { get; }
        public List<int>[] Adj { get; }

        public Graph(int vertices, int jumps = 3, int jumpLen = 100)
        {
            Vertices = vertices;
            Jumps = jumps;
            JumpLen = jumpLen;
            Adj = new List<int>[vertices];
            for (int i = 0; i < vertices; i++) Adj[i] = new List<int>();
        }

        public void AddEdge(int u, int v)
        {
            Adj[u].Add(v);
            Adj[v].Add(u);
        }

        public void GenerateRandom()
        {
            for (int i = 1; i < Vertices; i++)
            {
                AddEdge(i, i - 1);
            }

            for (int v = 0; v < Vertices; v++)
            {
                int numJumps = Helper.NextInt(Jumps);
                for (int j = 0; j < numJumps; j++)
                {
                    int offset = Helper.NextInt(JumpLen) - JumpLen / 2;
                    int u = v + offset;

                    if (u >= 0 && u < Vertices && u != v)
                    {
                        AddEdge(v, u);
                    }
                }
            }
        }
    }

    protected Graph _graph;
    protected uint _result;

    protected GraphPathBenchmark()
    {
        _result = 0;
    }

    public override void Prepare()
    {
        int vertices = (int)ConfigVal("vertices");
        int jumps = (int)ConfigVal("jumps");
        int jumpLen = (int)ConfigVal("jump_len");
        _graph = new Graph(vertices, jumps, jumpLen);
        _graph.GenerateRandom();
    }

    protected abstract long Test();

    public override void Run(long iterationId) => _result += (uint)Test();

    public override uint Checksum => _result;
    public override string TypeName => "Graph";
}

public class GraphPathBFS : GraphPathBenchmark
{
    protected override long Test()
    {
        return BfsShortestPath(0, _graph.Vertices - 1);
    }

    private int BfsShortestPath(int start, int target)
    {
        if (start == target) return 0;

        byte[] visited = new byte[_graph.Vertices];
        var queue = new Queue<(int vertex, int distance)>();

        visited[start] = 1;
        queue.Enqueue((start, 0));

        while (queue.Count > 0)
        {
            var (v, dist) = queue.Dequeue();

            foreach (int neighbor in _graph.Adj[v])
            {
                if (neighbor == target) return dist + 1;

                if (visited[neighbor] == 0)
                {
                    visited[neighbor] = 1;
                    queue.Enqueue((neighbor, dist + 1));
                }
            }
        }

        return -1;
    }
    public override string TypeName => "Graph::BFS";
}

public class GraphPathDFS : GraphPathBenchmark
{
    protected override long Test()
    {
        return DfsShortestPath(0, _graph.Vertices - 1);
    }

    private int DfsShortestPath(int start, int target)
    {
        if (start == target) return 0;

        byte[] visited = new byte[_graph.Vertices];
        var stack = new Stack<(int vertex, int distance)>();
        int bestPath = int.MaxValue;

        stack.Push((start, 0));

        while (stack.Count > 0)
        {
            var (v, dist) = stack.Pop();

            if (visited[v] == 1 || dist >= bestPath) continue;
            visited[v] = 1;

            foreach (int neighbor in _graph.Adj[v])
            {
                if (neighbor == target)
                {
                    if (dist + 1 < bestPath) bestPath = dist + 1;
                }
                else if (visited[neighbor] == 0)
                {
                    stack.Push((neighbor, dist + 1));
                }
            }
        }

        return bestPath == int.MaxValue ? -1 : bestPath;
    }
    public override string TypeName => "Graph::DFS";
}

public class GraphPathAStar : GraphPathBenchmark
{
    protected override long Test()
    {
        return AStarShortestPath(0, _graph.Vertices - 1);
    }

    private int Heuristic(int v, int target)
    {
        return target - v;
    }

    private int AStarShortestPath(int start, int target)
    {
        if (start == target) return 0;

        int[] gScore = new int[_graph.Vertices];
        int[] fScore = new int[_graph.Vertices];
        for (int i = 0; i < _graph.Vertices; i++)
        {
            gScore[i] = int.MaxValue;
            fScore[i] = int.MaxValue;
        }

        gScore[start] = 0;
        fScore[start] = Heuristic(start, target);

        var openSet = new PriorityQueue<(int vertex, int priority), int>(
            Comparer<int>.Create((a, b) => a.CompareTo(b))
        );
        openSet.Enqueue((start, fScore[start]), fScore[start]);

        var openSetHash = new HashSet<int>();
        openSetHash.Add(start);

        while (openSet.Count > 0)
        {
            var (current, _) = openSet.Dequeue();
            openSetHash.Remove(current);

            if (current == target)
            {
                return gScore[current];
            }

            foreach (int neighbor in _graph.Adj[current])
            {
                int tentativeG = gScore[current] + 1;

                if (tentativeG < gScore[neighbor])
                {
                    gScore[neighbor] = tentativeG;
                    int f = tentativeG + Heuristic(neighbor, target);
                    fScore[neighbor] = f;

                    if (!openSetHash.Contains(neighbor))
                    {
                        openSet.Enqueue((neighbor, f), f);
                        openSetHash.Add(neighbor);
                    }
                }
            }
        }

        return -1;
    }
    public override string TypeName => "Graph::AStar";
}