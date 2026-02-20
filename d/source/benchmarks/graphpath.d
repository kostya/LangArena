module benchmarks.graphpath;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.container;
import std.range;
import std.random;
import std.typecons;
import benchmark;
import helper;

class GraphPathBenchmark : Benchmark
{
protected:
    class Graph
    {
    public:
        int vertices;
        int jumps;
        int jumpLen;
        int[][] adj;

        this(int vertices, int jumps = 3, int jumpLen = 100)
        {
            this.vertices = vertices;
            this.jumps = jumps;
            this.jumpLen = jumpLen;
            adj = new int[][](vertices);
            foreach (i; 0 .. vertices)
            {
                adj[i] = [];
            }
        }

        void addEdge(int u, int v)
        {
            adj[u] ~= v;
            adj[v] ~= u;
        }

        void generateRandom()
        {
            foreach (i; 1 .. vertices)
            {
                addEdge(i, i - 1);
            }

            foreach (v; 0 .. vertices)
            {
                int numJumps = Helper.nextInt(jumps);
                foreach (j; 0 .. numJumps)
                {
                    int offset = Helper.nextInt(jumpLen) - jumpLen / 2;
                    int u = v + offset;

                    if (u >= 0 && u < vertices && u != v)
                    {
                        addEdge(v, u);
                    }
                }
            }
        }
    }

    Graph graph;
    uint resultVal;

    this()
    {
        resultVal = 0;
    }

    abstract long test();

    override void prepare()
    {
        int vertices = to!int(configVal("vertices"));
        int jumps = to!int(configVal("jumps"));
        int jumpLen = to!int(configVal("jump_len"));
        graph = new Graph(vertices, jumps, jumpLen);
        graph.generateRandom();
    }

    override void run(int iterationId)
    {
        resultVal += cast(uint) test();
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class GraphPathBFS : GraphPathBenchmark
{
private:
    int bfsShortestPath(int start, int target)
    {
        if (start == target)
            return 0;

        bool[] visited = new bool[graph.vertices];
        struct Node
        {
            int vertex;
            int distance;
        }

        Node[] queue = new Node[graph.vertices];
        int front = 0, back = 0;

        visited[start] = true;
        queue[back++] = Node(start, 0);

        while (front < back)
        {
            Node current = queue[front++];

            foreach (neighbor; graph.adj[current.vertex])
            {
                if (neighbor == target)
                    return current.distance + 1;

                if (!visited[neighbor])
                {
                    visited[neighbor] = true;
                    queue[back++] = Node(neighbor, current.distance + 1);
                }
            }
        }

        return -1;
    }

protected:
    override string className() const
    {
        return "GraphPathBFS";
    }

public:
    override long test()
    {
        return bfsShortestPath(0, graph.vertices - 1);
    }
}

class GraphPathDFS : GraphPathBenchmark
{
private:
    int dfsFindPath(int start, int target)
    {
        if (start == target)
            return 0;

        auto visited = new bool[graph.vertices];
        auto stack = new Tuple!(int, int)[graph.vertices];
        int top = 0;
        int bestPath = int.max;

        stack[top++] = tuple(start, 0);

        while (top > 0)
        {
            auto current = stack[--top];
            int v = current[0];
            int dist = current[1];

            if (visited[v] || dist >= bestPath)
                continue;
            visited[v] = true;

            foreach (neighbor; graph.adj[v])
            {
                if (neighbor == target)
                {
                    if (dist + 1 < bestPath)
                        bestPath = dist + 1;
                }
                else if (!visited[neighbor])
                {
                    stack[top++] = tuple(neighbor, dist + 1);
                }
            }
        }

        return bestPath == int.max ? -1 : bestPath;
    }

protected:
    override string className() const
    {
        return "GraphPathDFS";
    }

public:
    override long test()
    {
        return dfsFindPath(0, graph.vertices - 1);
    }
}

class GraphPathAStar : GraphPathBenchmark
{
private:
    struct PriorityQueueItem
    {
        int vertex;
        int priority;
    }

    struct PriorityQueue
    {
        PriorityQueueItem[] items;
        int size;

        static PriorityQueue opCall()
        {
            PriorityQueue pq;
            pq.items = new PriorityQueueItem[16];
            pq.size = 0;
            return pq;
        }

        void push(int vertex, int priority)
        {
            if (size >= items.length)
            {
                items.length *= 2;
            }

            int i = size++;
            while (i > 0)
            {
                int parent = (i - 1) / 2;
                if (items[parent].priority <= priority)
                    break;
                items[i] = items[parent];
                i = parent;
            }
            items[i] = PriorityQueueItem(vertex, priority);
        }

        PriorityQueueItem pop()
        {
            auto min = items[0];
            size--;

            if (size > 0)
            {
                auto last = items[size];
                int i = 0;

                while (true)
                {
                    int left = 2 * i + 1;
                    int right = 2 * i + 2;
                    int smallest = i;

                    if (left < size && items[left].priority < items[smallest].priority)
                        smallest = left;
                    if (right < size && items[right].priority < items[smallest].priority)
                        smallest = right;

                    if (smallest == i)
                        break;

                    items[i] = items[smallest];
                    i = smallest;
                }

                items[i] = last;
            }

            return min;
        }

        bool empty() const
        {
            return size == 0;
        }
    }

    int heuristic(int v, int target)
    {
        return target - v;
    }

    int aStarShortestPath(int start, int target)
    {
        if (start == target)
            return 0;

        int[] gScore = new int[graph.vertices];
        int[] fScore = new int[graph.vertices];
        bool[] visited = new bool[graph.vertices];

        foreach (i; 0 .. graph.vertices)
        {
            gScore[i] = int.max;
            fScore[i] = int.max;
        }
        gScore[start] = 0;
        fScore[start] = heuristic(start, target);

        auto openSet = PriorityQueue.opCall();
        openSet.push(start, fScore[start]);

        bool[] inOpenSet = new bool[graph.vertices];
        inOpenSet[start] = true;

        while (!openSet.empty())
        {
            auto current = openSet.pop();
            inOpenSet[current.vertex] = false;

            if (current.vertex == target)
            {
                return gScore[current.vertex];
            }

            visited[current.vertex] = true;

            foreach (neighbor; graph.adj[current.vertex])
            {
                if (visited[neighbor])
                    continue;

                int tentativeG = gScore[current.vertex] + 1;

                if (tentativeG < gScore[neighbor])
                {
                    gScore[neighbor] = tentativeG;
                    int f = tentativeG + heuristic(neighbor, target);
                    fScore[neighbor] = f;

                    if (!inOpenSet[neighbor])
                    {
                        openSet.push(neighbor, f);
                        inOpenSet[neighbor] = true;
                    }
                }
            }
        }

        return -1;
    }

protected:
    override string className() const
    {
        return "GraphPathAStar";
    }

public:
    override long test()
    {
        return aStarShortestPath(0, graph.vertices - 1);
    }
}
