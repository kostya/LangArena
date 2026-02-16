module benchmarks.gameoflife;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.random;
import std.range;

import benchmark;
import helper;

class GameOfLife : Benchmark {
private:

    class Cell {
    public:
        bool alive;
        bool nextState;
        Cell[] neighbors;

        this() {
            alive = false;
            nextState = false;
            neighbors.length = 0;
        }

        void addNeighbor(Cell cell) {
            neighbors ~= cell;
        }

        void computeNextState() {
            int aliveNeighbors = 0;
            foreach (n; neighbors) {
                if (n.alive) aliveNeighbors++;
            }

            if (alive) {
                nextState = (aliveNeighbors == 2 || aliveNeighbors == 3);
            } else {
                nextState = (aliveNeighbors == 3);
            }
        }

        void update() {
            alive = nextState;
        }
    }

    class Grid {
    private:
        int width;
        int height;
        Cell[][] cells;      

    public:
        this(int w, int h) {
            width = w;
            height = h;

            cells.length = height;
            for (int y = 0; y < height; ++y) {
                cells[y].length = width;
                for (int x = 0; x < width; ++x) {
                    cells[y][x] = new Cell();
                }
            }

            linkNeighbors();
        }

    private:
        void linkNeighbors() {
            for (int y = 0; y < height; ++y) {
                for (int x = 0; x < width; ++x) {
                    auto cell = cells[y][x];

                    for (int dy = -1; dy <= 1; ++dy) {
                        for (int dx = -1; dx <= 1; ++dx) {
                            if (dx == 0 && dy == 0) continue;

                            int ny = (y + dy + height) % height;
                            int nx = (x + dx + width) % width;

                            cell.addNeighbor(cells[ny][nx]);
                        }
                    }
                }
            }
        }

    public:
        void nextGeneration() {

            foreach (row; cells) {
                foreach (cell; row) {
                    cell.computeNextState();
                }
            }

            foreach (row; cells) {
                foreach (cell; row) {
                    cell.update();
                }
            }
        }

        int countAlive() const {
            int count = 0;
            foreach (row; cells) {
                foreach (cell; row) {
                    if (cell.alive) count++;
                }
            }
            return count;
        }

        uint computeHash() const {
            enum FNV_OFFSET_BASIS = 2166136261u;
            enum FNV_PRIME = 16777619u;

            uint hash = FNV_OFFSET_BASIS;
            foreach (row; cells) {
                foreach (cell; row) {
                    uint alive = cast(uint)(cell.alive ? 1 : 0);
                    hash = cast(uint)((hash ^ alive) * FNV_PRIME);
                }
            }
            return hash;
        }

        Cell[][] getCells() { return cells; }
        int getWidth() const { return width; }
        int getHeight() const { return height; }
    }

    uint resultVal;
    int width;
    int height;
    Grid grid;

protected:
    override string className() const { return "GameOfLife"; }

public:
    this() {
        resultVal = 0;
        width = configVal("w");
        height = configVal("h");
        grid = new Grid(width, height);
    }

    override void prepare() {
        foreach (row; grid.getCells()) {
            foreach (cell; row) {
                if (Helper.nextFloat(1.0) < 0.1) {
                    cell.alive = true;
                }
            }
        }
    }

    override void run(int iterationId) {
        grid.nextGeneration();
    }

    override uint checksum() {
        int alive = grid.countAlive();
        return grid.computeHash() + alive;
    }
}