public class GraphPathBFS : GraphPathBenchmark
{
    protected override long Test()
    {
        long totalLength = 0;

        foreach (var (start, end) in _pairs)
        {
            int length = BfsShortestPath(start, end);
            totalLength += length;
        }

        return totalLength;
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
}