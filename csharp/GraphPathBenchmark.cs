public abstract class GraphPathBenchmark : Benchmark
{
    protected class Graph
    {
        public int Vertices { get; }
        public List<int>[] Adj { get; }
        private readonly int _components;

        public Graph(int vertices, int components = 10)
        {
            Vertices = vertices;
            _components = components;
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
            int componentSize = Vertices / _components;

            for (int c = 0; c < _components; c++)
            {
                int startIdx = c * componentSize;
                int endIdx = (c + 1) * componentSize;
                if (c == _components - 1) endIdx = Vertices;

                for (int i = startIdx + 1; i < endIdx; i++)
                {
                    int parent = startIdx + Helper.NextInt(i - startIdx);
                    AddEdge(i, parent);
                }

                for (int i = 0; i < componentSize * 2; i++)
                {
                    int u = startIdx + Helper.NextInt(endIdx - startIdx);
                    int v = startIdx + Helper.NextInt(endIdx - startIdx);
                    if (u != v) AddEdge(u, v);
                }
            }
        }
    }

    protected Graph _graph;
    protected List<(int, int)> _pairs;
    protected uint _result;
    protected long _nPairs;

    protected GraphPathBenchmark()
    {
        _result = 0;
        _nPairs = ConfigVal("pairs");
    }

    protected List<(int, int)> GeneratePairs(int n)
    {
        var pairs = new List<(int, int)>();
        int componentSize = _graph.Vertices / 10;

        for (int i = 0; i < n; i++)
        {
            if (Helper.NextInt(100) < 70)
            {
                int component = Helper.NextInt(10);
                int start = component * componentSize + Helper.NextInt(componentSize);
                int end;
                do { end = component * componentSize + Helper.NextInt(componentSize); } while (end == start);
                pairs.Add((start, end));
            }
            else
            {
                int c1 = Helper.NextInt(10);
                int c2;
                do { c2 = Helper.NextInt(10); } while (c2 == c1);

                int start = c1 * componentSize + Helper.NextInt(componentSize);
                int end = c2 * componentSize + Helper.NextInt(componentSize);
                pairs.Add((start, end));
            }
        }

        return pairs;
    }

    public override void Prepare()
    {
        int vertices = (int)ConfigVal("vertices");
        int comps = Math.Max(10, vertices / 10000);
        _graph = new Graph(vertices, comps);
        _graph.GenerateRandom();
        _pairs = GeneratePairs((int)_nPairs);
    }

    protected abstract long Test();

    public override void Run(long IterationId) => _result += (uint)Test();

    public override uint Checksum => _result;
}