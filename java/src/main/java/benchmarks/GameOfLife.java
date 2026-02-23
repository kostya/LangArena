package benchmarks;

import java.util.*;

public class GameOfLife extends Benchmark {
    private static class Cell {
        private boolean alive;
        private boolean nextState;
        private Cell[] neighbors;
        private int neighborCount;

        public Cell(boolean alive) {
            this.alive = alive;
            this.nextState = false;
            this.neighbors = new Cell[8];
        }

        public void addNeighbor(Cell cell) {
            neighbors[neighborCount++] = cell;
        }

        public void computeNextState() {
            int aliveNeighbors = 0;
            for (Cell neighbor : neighbors) {
                if (neighbor.alive) aliveNeighbors++;
            }

            if (alive) {
                nextState = (aliveNeighbors == 2 || aliveNeighbors == 3);
            } else {
                nextState = (aliveNeighbors == 3);
            }
        }

        public void update() {
            alive = nextState;
        }

        public void setAlive(boolean state) {
            alive = state;
        }

        public boolean isAlive() {
            return alive;
        }
    }

    private static class Grid {
        private final int width;
        private final int height;
        private final Cell[][] cells;

        public Grid(int width, int height) {
            this.width = width;
            this.height = height;
            this.cells = new Cell[height][width];

            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    cells[y][x] = new Cell(false);
                }
            }

            linkNeighbors();
        }

        private void linkNeighbors() {
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    Cell cell = cells[y][x];

                    for (int dy = -1; dy <= 1; dy++) {
                        for (int dx = -1; dx <= 1; dx++) {
                            if (dx == 0 && dy == 0) continue;

                            int ny = (y + dy + height) % height;
                            int nx = (x + dx + width) % width;

                            cell.addNeighbor(cells[ny][nx]);
                        }
                    }
                }
            }
        }

        public void nextGeneration() {
            for (Cell[] row : cells) {
                for (Cell cell : row) {
                    cell.computeNextState();
                }
            }

            for (Cell[] row : cells) {
                for (Cell cell : row) {
                    cell.update();
                }
            }
        }

        public int countAlive() {
            int count = 0;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    if (cells[y][x].isAlive()) count++;
                }
            }
            return count;
        }

        public long computeHash() {
            final long FNV_OFFSET_BASIS = 2166136261L;
            final long FNV_PRIME = 16777619L;

            long hash = FNV_OFFSET_BASIS;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    long alive = cells[y][x].isAlive() ? 1L : 0L;
                    hash = (hash ^ alive) * FNV_PRIME;
                }
            }
            return hash;
        }

        public Cell[][] getCells() {
            return cells;
        }
    }

    private final int width;
    private final int height;
    private Grid grid;

    public GameOfLife() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.grid = new Grid(width, height);
    }

    @Override
    public String name() {
        return "Etc::GameOfLife";
    }

    @Override
    public void prepare() {
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (Helper.nextFloat() < 0.1f) {
                    grid.getCells()[y][x].setAlive(true);
                }
            }
        }
    }

    @Override
    public void run(int iterationId) {
        grid.nextGeneration();
    }

    @Override
    public long checksum() {
        int alive = grid.countAlive();
        return grid.computeHash() + alive;
    }
}