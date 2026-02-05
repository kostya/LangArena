public class GraphPathDijkstra : GraphPathBenchmark
{
    private const int INF = int.MaxValue / 2;

    protected override long Test()
    {
        long totalLength = 0;

        foreach (var (start, end) in _pairs)
        {
            int length = DijkstraShortestPath(start, end);
            totalLength += length;
        }

        return totalLength;
    }

    private int DijkstraShortestPath(int start, int target)
    {
        if (start == target) return 0;

        int[] dist = new int[_graph.Vertices];
        byte[] visited = new byte[_graph.Vertices];

        for (int i = 0; i < _graph.Vertices; i++) dist[i] = INF;

        dist[start] = 0;
        int maxIterations = _graph.Vertices;

        for (int iteration = 0; iteration < maxIterations; iteration++)
        {
            int u = -1;
            int minDist = INF;

            for (int v = 0; v < _graph.Vertices; v++)
            {
                if (visited[v] == 0 && dist[v] < minDist)
                {
                    minDist = dist[v];
                    u = v;
                }
            }

            if (u == -1 || minDist == INF || u == target)
            {
                return (u == target) ? minDist : -1;
            }

            visited[u] = 1;

            foreach (int v in _graph.Adj[u])
            {
                if (dist[u] + 1 < dist[v]) dist[v] = dist[u] + 1;
            }
        }

        return -1;
    }
}