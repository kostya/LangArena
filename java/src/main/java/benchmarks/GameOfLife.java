package benchmarks;

import java.util.*;

public class GameOfLife extends Benchmark {
    private enum Cell {
        DEAD, ALIVE
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
                Arrays.fill(cells[y], Cell.DEAD);
            }
        }
        
        public Cell get(int x, int y) {
            return cells[y][x];
        }
        
        public void set(int x, int y, Cell cell) {
            cells[y][x] = cell;
        }
        
        public int countNeighbors(int x, int y) {
            int count = 0;
            
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    
                    // Тороидальные координаты
                    int nx = (x + dx) % width;
                    int ny = (y + dy) % height;
                    if (nx < 0) nx += width;
                    if (ny < 0) ny += height;
                    
                    if (cells[ny][nx] == Cell.ALIVE) {
                        count++;
                    }
                }
            }
            
            return count;
        }
        
        public Grid nextGeneration() {
            Grid nextGrid = new Grid(width, height);
            
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int neighbors = countNeighbors(x, y);
                    Cell current = cells[y][x];
                    
                    Cell nextState = Cell.DEAD;
                    if (current == Cell.ALIVE) {
                        if (neighbors == 2 || neighbors == 3) {
                            nextState = Cell.ALIVE;
                        }
                    } else {
                        if (neighbors == 3) {
                            nextState = Cell.ALIVE;
                        }
                    }
                    
                    nextGrid.cells[y][x] = nextState;
                }
            }
            
            return nextGrid;
        }
        
        public int aliveCount() {
            int count = 0;
            for (Cell[] row : cells) {
                for (Cell cell : row) {
                    if (cell == Cell.ALIVE) {
                        count++;
                    }
                }
            }
            return count;
        }
    }
    
    private long resultVal;
    private final int width;
    private final int height;
    private Grid grid;
    
    public GameOfLife() {
        this.width = 256;
        this.height = 256;
        this.grid = new Grid(width, height);
    }
    
    @Override
    public void prepare() {
        // Инициализация случайными клетками
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (Helper.nextFloat() < 0.1f) {
                    grid.set(x, y, Cell.ALIVE);
                }
            }
        }
    }
    
    @Override
    public void run() {
        // Основной цикл симуляции
        int iters = getIterations();
        for (int i = 0; i < iters; i++) {
            grid = grid.nextGeneration();
        }
        
        resultVal = grid.aliveCount();
    }
    
    @Override
    public long getResult() {
        return resultVal;
    }
}