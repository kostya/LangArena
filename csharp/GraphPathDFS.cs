public class GraphPathDFS : GraphPathBenchmark
{
    protected override long Test()
    {
        long totalLength = 0;

        foreach (var (start, end) in _pairs)
        {
            int length = DfsFindPath(start, end);
            totalLength += length;
        }

        return totalLength;
    }

    private int DfsFindPath(int start, int target)
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
}