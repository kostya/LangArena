module benchmarks.astarpathfinder;

import benchmark;
import helper;
import std.stdio;
import std.algorithm;
import std.container;
import std.conv;
import std.array;
import std.range;
import std.typecons;
import std.math;
import std.exception;

import benchmarks.mazegenerator : MazeGenerator;

class AStarPathfinder : Benchmark
{
private:
    enum INF = int.max;
    enum STRAIGHT_COST = 1000;

    struct Node
    {
        int x, y, fScore;

        int opCmp(ref const Node other) const
        {
            if (fScore != other.fScore)
                return fScore - other.fScore;
            if (y != other.y)
                return y - other.y;
            return x - other.x;
        }

        bool opEquals(ref const Node other) const
        {
            return x == other.x && y == other.y && fScore == other.fScore;
        }
    }

    uint resultVal = 0;
    int width_ = 0;
    int height_ = 0;
    int startX_ = 1;
    int startY_ = 1;
    int goalX_ = 0;
    int goalY_ = 0;

    bool[][] mazeGrid_;

    int[] gScores_;
    int[] cameFrom_;

    int heuristic(int x1, int y1, int x2, int y2) const
    {
        return abs(x1 - x2) + abs(y1 - y2);
    }

    int packCoords(int x, int y) const
    {
        return y * width_ + x;
    }

    Tuple!(int, int) unpackCoords(int idx) const
    {
        return tuple(idx % width_, idx / width_);
    }

    Tuple!(Tuple!(int, int)[], int) findPath()
    {
        const int size = width_ * height_;
        const int startIdx = packCoords(startX_, startY_);
        const int goalIdx = packCoords(goalX_, goalY_);

        gScores_[] = INF;
        cameFrom_[] = -1;

        auto openSet = heapify!((a, b) => a.opCmp(b) > 0)(Array!Node());

        gScores_[startIdx] = 0;
        openSet.insert(Node(startX_, startY_, heuristic(startX_, startY_, goalX_, goalY_)));

        int nodesExplored = 0;
        static immutable Tuple!(int, int)[] directions = [
            tuple(0, -1), tuple(1, 0), tuple(0, 1), tuple(-1, 0)
        ];

        while (!openSet.empty())
        {
            Node current = openSet.front();
            openSet.removeFront();
            nodesExplored++;

            if (current.x == goalX_ && current.y == goalY_)
            {

                Tuple!(int, int)[] path;
                path.reserve(width_ + height_);

                int x = current.x;
                int y = current.y;

                while (x != startX_ || y != startY_)
                {
                    path ~= tuple(x, y);
                    int idx = packCoords(x, y);
                    int packed = cameFrom_[idx];
                    if (packed == -1)
                        break;

                    auto unpacked = unpackCoords(packed);
                    x = unpacked[0];
                    y = unpacked[1];
                }

                path ~= tuple(startX_, startY_);
                path.reverse();
                return tuple(path, nodesExplored);
            }

            int currentIdx = packCoords(current.x, current.y);
            int currentG = gScores_[currentIdx];

            foreach (dir; directions)
            {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];

                if (nx < 0 || nx >= width_ || ny < 0 || ny >= height_)
                    continue;
                if (!mazeGrid_[ny][nx])
                    continue;

                int tentativeG = currentG + STRAIGHT_COST;
                int neighborIdx = packCoords(nx, ny);

                if (tentativeG < gScores_[neighborIdx])
                {
                    cameFrom_[neighborIdx] = currentIdx;
                    gScores_[neighborIdx] = tentativeG;

                    int fScore = tentativeG + heuristic(nx, ny, goalX_, goalY_);
                    openSet.insert(Node(nx, ny, fScore));
                }
            }
        }

        return tuple((Tuple!(int, int)[]).init, nodesExplored);
    }

public:
    this()
    {
        width_ = configVal("w");
        height_ = configVal("h");
        goalX_ = width_ - 2;
        goalY_ = height_ - 2;
    }

    override string className() const
    {
        return "AStarPathfinder";
    }

    override void prepare()
    {

        mazeGrid_ = generateMaze(width_, height_);

        int size = width_ * height_;
        gScores_ = new int[size];
        cameFrom_ = new int[size];
    }

    private bool[][] generateMaze(int width, int height)
    {

        auto mazeGen = new MazeGenerator();

        import std.conv : to;

        return MazeGenerator.Maze.generateWalkableMaze(width, height);
    }

    override void run(int iterationId)
    {
        auto result = findPath();
        auto path = result[0];
        int nodesExplored = result[1];

        long localResult = 0;
        if (!path.empty)
        {
            localResult = (localResult << 5) + cast(long)(path.length);
        }
        localResult = (localResult << 5) + nodesExplored;
        resultVal += cast(uint) localResult;
    }

    override uint checksum()
    {
        return resultVal;
    }
}
