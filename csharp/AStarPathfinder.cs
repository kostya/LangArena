using System;
using System.Collections.Generic;

public class AStarPathfinder : Benchmark
{
    private interface IHeuristic
    {
        int Distance(int aX, int aY, int bX, int bY);
    }
    
    private class ManhattanHeuristic : IHeuristic
    {
        public int Distance(int aX, int aY, int bX, int bY)
            => (Math.Abs(aX - bX) + Math.Abs(aY - bY)) * 1000;
    }
    
    private class EuclideanHeuristic : IHeuristic
    {
        public int Distance(int aX, int aY, int bX, int bY)
        {
            double dx = Math.Abs(aX - bX);
            double dy = Math.Abs(aY - bY);
            return (int)(Math.Sqrt(dx * dx + dy * dy) * 1000.0);
        }
    }
    
    private class ChebyshevHeuristic : IHeuristic
    {
        public int Distance(int aX, int aY, int bX, int bY)
            => Math.Max(Math.Abs(aX - bX), Math.Abs(aY - bY)) * 1000;
    }
    
    private class Node : IComparable<Node>
    {
        public int X { get; }
        public int Y { get; }
        public int FScore { get; }
        
        public Node(int x, int y, int fScore)
        {
            X = x;
            Y = y;
            FScore = fScore;
        }
        
        public int CompareTo(Node? other)
        {
            if (other == null) return 1;
            
            // Сортировка по fScore, затем по координатам для стабильности
            if (FScore != other.FScore)
                return FScore.CompareTo(other.FScore);
            if (Y != other.Y)
                return Y.CompareTo(other.Y);
            return X.CompareTo(other.X);
        }
    }
    
    private class BinaryHeap
    {
        private readonly List<Node> _data = new List<Node>();
        
        public void Push(Node item)
        {
            _data.Add(item);
            SiftUp(_data.Count - 1);
        }
        
        public Node? Pop()
        {
            if (_data.Count == 0) return null;
            
            if (_data.Count == 1)
            {
                Node result = _data[0];
                _data.RemoveAt(0);
                return result;
            }
            
            Node resultNode = _data[0];
            _data[0] = _data[_data.Count - 1];
            _data.RemoveAt(_data.Count - 1);
            SiftDown(0);
            return resultNode;
        }
        
        public bool IsEmpty() => _data.Count == 0;
        
        private void SiftUp(int index)
        {
            while (index > 0)
            {
                int parent = (index - 1) / 2;
                if (_data[index].CompareTo(_data[parent]) >= 0) break;
                (_data[index], _data[parent]) = (_data[parent], _data[index]);
                index = parent;
            }
        }
        
        private void SiftDown(int index)
        {
            int size = _data.Count;
            while (true)
            {
                int left = index * 2 + 1;
                int right = left + 1;
                int smallest = index;
                
                if (left < size && _data[left].CompareTo(_data[smallest]) < 0)
                    smallest = left;
                
                if (right < size && _data[right].CompareTo(_data[smallest]) < 0)
                    smallest = right;
                
                if (smallest == index) break;
                
                (_data[index], _data[smallest]) = (_data[smallest], _data[index]);
                index = smallest;
            }
        }
    }
    
    private long _resultVal;
    private readonly int _startX;
    private readonly int _startY;
    private readonly int _goalX;
    private readonly int _goalY;
    private readonly int _width;
    private readonly int _height;
    private bool[,]? _mazeGrid;
    
    public AStarPathfinder()
    {
        _width = Iterations;
        _height = Iterations;
        _startX = 1;
        _startY = 1;
        _goalX = _width - 2;
        _goalY = _height - 2;
    }
    
    private bool[,] GenerateWalkableMaze(int width, int height)
    {
        return MazeGenerator.Maze.GenerateWalkableMaze(width, height);
    }
    
    private bool[,] EnsureMazeGrid()
    {
        if (_mazeGrid == null)
            _mazeGrid = GenerateWalkableMaze(_width, _height);
        return _mazeGrid;
    }
    
    private List<(int x, int y)>? FindPath(IHeuristic heuristic, bool allowDiagonal = false)
    {
        bool[,] grid = EnsureMazeGrid();
        
        int[,] gScores = new int[_height, _width];
        (int x, int y)[,] cameFrom = new (int, int)[_height, _width];
        
        for (int y = 0; y < _height; y++)
        {
            for (int x = 0; x < _width; x++)
            {
                gScores[y, x] = int.MaxValue;
                cameFrom[y, x] = (-1, -1);
            }
        }
        
        BinaryHeap openSet = new BinaryHeap();
        
        gScores[_startY, _startX] = 0;
        openSet.Push(new Node(_startX, _startY, 
                             heuristic.Distance(_startX, _startY, _goalX, _goalY)));
        
        List<(int dx, int dy)> directions = allowDiagonal ? new List<(int, int)>
        {
            (0, -1), (1, 0), (0, 1), (-1, 0),
            (-1, -1), (1, -1), (1, 1), (-1, 1)
        } : new List<(int, int)>
        {
            (0, -1), (1, 0), (0, 1), (-1, 0)
        };
        
        int diagonalCost = allowDiagonal ? 1414 : 1000;
        
        while (!openSet.IsEmpty())
        {
            Node? current = openSet.Pop();
            if (current == null) break;
            
            if (current.X == _goalX && current.Y == _goalY)
            {
                List<(int x, int y)> path = new List<(int, int)>();
                int x = current.X;
                int y = current.Y;
                
                while (x != _startX || y != _startY)
                {
                    path.Add((x, y));
                    var (prevX, prevY) = cameFrom[y, x];
                    x = prevX;
                    y = prevY;
                }
                
                path.Add((_startX, _startY));
                path.Reverse();
                return path;
            }
            
            int currentG = gScores[current.Y, current.X];
            
            foreach (var (dx, dy) in directions)
            {
                int nx = current.X + dx;
                int ny = current.Y + dy;
                
                if (nx < 0 || nx >= _width || ny < 0 || ny >= _height) continue;
                if (!grid[ny, nx]) continue;
                
                int moveCost = (Math.Abs(dx) == 1 && Math.Abs(dy) == 1) ? diagonalCost : 1000;
                int tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny, nx])
                {
                    cameFrom[ny, nx] = (current.X, current.Y);
                    gScores[ny, nx] = tentativeG;
                    
                    int fScore = tentativeG + heuristic.Distance(nx, ny, _goalX, _goalY);
                    openSet.Push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return null;
    }
    
    private int EstimateNodesExplored(IHeuristic heuristic, bool allowDiagonal = false)
    {
        bool[,] grid = EnsureMazeGrid();
        
        int[,] gScores = new int[_height, _width];
        for (int y = 0; y < _height; y++)
            for (int x = 0; x < _width; x++)
                gScores[y, x] = int.MaxValue;
        
        BinaryHeap openSet = new BinaryHeap();
        bool[,] closed = new bool[_height, _width];
        
        gScores[_startY, _startX] = 0;
        openSet.Push(new Node(_startX, _startY, 
                             heuristic.Distance(_startX, _startY, _goalX, _goalY)));
        
        List<(int dx, int dy)> directions = allowDiagonal ? new List<(int, int)>
        {
            (0, -1), (1, 0), (0, 1), (-1, 0),
            (-1, -1), (1, -1), (1, 1), (-1, 1)
        } : new List<(int, int)>
        {
            (0, -1), (1, 0), (0, 1), (-1, 0)
        };
        
        int nodesExplored = 0;
        
        while (!openSet.IsEmpty())
        {
            Node? current = openSet.Pop();
            if (current == null) break;
            
            if (current.X == _goalX && current.Y == _goalY)
                break;
            
            if (closed[current.Y, current.X]) continue;
            
            closed[current.Y, current.X] = true;
            nodesExplored++;
            
            int currentG = gScores[current.Y, current.X];
            
            foreach (var (dx, dy) in directions)
            {
                int nx = current.X + dx;
                int ny = current.Y + dy;
                
                if (nx < 0 || nx >= _width || ny < 0 || ny >= _height) continue;
                if (!grid[ny, nx]) continue;
                
                int moveCost = (Math.Abs(dx) == 1 && Math.Abs(dy) == 1) ? 1414 : 1000;
                int tentativeG = currentG + moveCost;
                
                if (tentativeG < gScores[ny, nx])
                {
                    gScores[ny, nx] = tentativeG;
                    
                    int fScore = tentativeG + heuristic.Distance(nx, ny, _goalX, _goalY);
                    openSet.Push(new Node(nx, ny, fScore));
                }
            }
        }
        
        return nodesExplored;
    }
    
    private (int pathsFound, int pathLength, int nodesExplored) BenchmarkDifferentApproaches()
    {
        List<IHeuristic> heuristics = new List<IHeuristic>
        {
            new ManhattanHeuristic(),
            new EuclideanHeuristic(),
            new ChebyshevHeuristic()
        };
        
        int totalPathsFound = 0;
        int totalPathLength = 0;
        int totalNodesExplored = 0;
        
        foreach (var heuristic in heuristics)
        {
            var path = FindPath(heuristic, false);
            if (path != null)
            {
                totalPathsFound++;
                totalPathLength += path.Count;
                totalNodesExplored += EstimateNodesExplored(heuristic, false);
            }
        }
        
        return (totalPathsFound, totalPathLength, totalNodesExplored);
    }
    
    public override void Prepare()
    {
        EnsureMazeGrid();
    }
    
    public override void Run()
    {
        int totalPathsFound = 0;
        int totalPathLength = 0;
        int totalNodesExplored = 0;
        
        int iters = 10;
        for (int i = 0; i < iters; i++)
        {
            var (pathsFound, pathLength, nodesExplored) = BenchmarkDifferentApproaches();
            
            totalPathsFound += pathsFound;
            totalPathLength += pathLength;
            totalNodesExplored += nodesExplored;
        }
        
        long pathsChecksum = Helper.Checksum(totalPathsFound);
        long lengthChecksum = Helper.Checksum(totalPathLength);
        long nodesChecksum = Helper.Checksum(totalNodesExplored);
        
        _resultVal = (pathsChecksum) ^
                   ((lengthChecksum) << 16) ^
                   ((nodesChecksum) << 32);
    }
    
    public override long Result => _resultVal;
}