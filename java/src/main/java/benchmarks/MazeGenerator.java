package benchmarks;

import java.util.*;

public class MazeGenerator extends Benchmark {
    private enum Cell {
        WALL, PATH
    }

    public static class Maze {
        private final int width;
        private final int height;
        private final Cell[][] cells;

        public Maze(int width, int height) {
            this.width = width > 5 ? width : 5;
            this.height = height > 5 ? height : 5;
            this.cells = new Cell[height][width];
            for (int y = 0; y < height; y++) {
                Arrays.fill(cells[y], Cell.WALL);
            }
        }

        public Cell get(int x, int y) {
            return cells[y][x];
        }

        public void set(int x, int y, Cell cell) {
            cells[y][x] = cell;
        }

        private void divide(int x1, int y1, int x2, int y2) {
            int width = x2 - x1;
            int height = y2 - y1;

            if (width < 2 || height < 2) return;

            int widthForWall = Math.max(width - 2, 0);
            int heightForWall = Math.max(height - 2, 0);
            int widthForHole = Math.max(width - 1, 0);
            int heightForHole = Math.max(height - 1, 0);

            if (widthForWall == 0 || heightForWall == 0 ||
                    widthForHole == 0 || heightForHole == 0) return;

            if (width > height) {

                int wallRange = Math.max(widthForWall / 2, 1);
                int wallOffset = wallRange > 0 ? (Helper.nextInt(wallRange)) * 2 : 0;
                int wallX = x1 + 2 + wallOffset;

                int holeRange = Math.max(heightForHole / 2, 1);
                int holeOffset = holeRange > 0 ? (Helper.nextInt(holeRange)) * 2 : 0;
                int holeY = y1 + 1 + holeOffset;

                if (wallX > x2 || holeY > y2) return;

                for (int y = y1; y <= y2; y++) {
                    if (y != holeY) {
                        set(wallX, y, Cell.WALL);
                    }
                }

                if (wallX > x1 + 1) divide(x1, y1, wallX - 1, y2);
                if (wallX + 1 < x2) divide(wallX + 1, y1, x2, y2);
            } else {

                int wallRange = Math.max(heightForWall / 2, 1);
                int wallOffset = wallRange > 0 ? (Helper.nextInt(wallRange)) * 2 : 0;
                int wallY = y1 + 2 + wallOffset;

                int holeRange = Math.max(widthForHole / 2, 1);
                int holeOffset = holeRange > 0 ? (Helper.nextInt(holeRange)) * 2 : 0;
                int holeX = x1 + 1 + holeOffset;

                if (wallY > y2 || holeX > x2) return;

                for (int x = x1; x <= x2; x++) {
                    if (x != holeX) {
                        set(x, wallY, Cell.WALL);
                    }
                }

                if (wallY > y1 + 1) divide(x1, y1, x2, wallY - 1);
                if (wallY + 1 < y2) divide(x1, wallY + 1, x2, y2);
            }
        }

        private boolean isConnectedImpl(int startX, int startY, int goalX, int goalY) {
            if (startX >= width || startY >= height ||
                    goalX >= width || goalY >= height) {
                return false;
            }

            boolean[][] visited = new boolean[height][width];
            Deque<int[]> queue = new ArrayDeque<>();

            visited[startY][startX] = true;
            queue.add(new int[] {startX, startY});

            while (!queue.isEmpty()) {
                int[] current = queue.poll();
                int x = current[0];
                int y = current[1];

                if (x == goalX && y == goalY) return true;

                if (y > 0 && get(x, y - 1) == Cell.PATH && !visited[y - 1][x]) {
                    visited[y - 1][x] = true;
                    queue.add(new int[] {x, y - 1});
                }

                if (x + 1 < width && get(x + 1, y) == Cell.PATH && !visited[y][x + 1]) {
                    visited[y][x + 1] = true;
                    queue.add(new int[] {x + 1, y});
                }

                if (y + 1 < height && get(x, y + 1) == Cell.PATH && !visited[y + 1][x]) {
                    visited[y + 1][x] = true;
                    queue.add(new int[] {x, y + 1});
                }

                if (x > 0 && get(x - 1, y) == Cell.PATH && !visited[y][x - 1]) {
                    visited[y][x - 1] = true;
                    queue.add(new int[] {x - 1, y});
                }
            }

            return false;
        }

        public void generate() {
            if (width < 5 || height < 5) {
                for (int x = 0; x < width; x++) {
                    set(x, height / 2, Cell.PATH);
                }
                return;
            }

            divide(0, 0, width - 1, height - 1);

            addRandomPaths();
        }

        private void addRandomPaths() {
            int numExtraPaths = (width * height) / 20;

            for (int i = 0; i < numExtraPaths; i++) {
                int x = Helper.nextInt(width - 2) + 1;
                int y = Helper.nextInt(height - 2) + 1;

                if (get(x, y) == Cell.WALL &&
                        get(x - 1, y) == Cell.WALL &&
                        get(x + 1, y) == Cell.WALL &&
                        get(x, y - 1) == Cell.WALL &&
                        get(x, y + 1) == Cell.WALL) {
                    set(x, y, Cell.PATH);
                }
            }
        }

        public boolean[][] toBoolGrid() {
            boolean[][] result = new boolean[height][width];

            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    result[y][x] = (cells[y][x] == Cell.PATH);
                }
            }

            return result;
        }

        public boolean isConnected(int startX, int startY, int goalX, int goalY) {
            return isConnectedImpl(startX, startY, goalX, goalY);
        }

        public static boolean[][] generateWalkableMaze(int width, int height) {
            Maze maze = new Maze(width, height);
            maze.generate();

            int startX = 1;
            int startY = 1;
            int goalX = width - 2;
            int goalY = height - 2;

            if (!maze.isConnected(startX, startY, goalX, goalY)) {
                for (int x = 0; x < width; x++) {
                    for (int y = 0; y < height; y++) {
                        if (x < maze.width && y < maze.height) {
                            if (x == 1 || y == 1 || x == width - 2 || y == height - 2) {
                                maze.set(x, y, Cell.PATH);
                            }
                        }
                    }
                }
            }

            return maze.toBoolGrid();
        }
    }

    private long resultVal;
    private final int width;
    private final int height;
    private boolean[][] boolGrid;

    public MazeGenerator() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.resultVal = 0L;
    }

    @Override
    public String name() {
        return "MazeGenerator";
    }

    private long gridChecksum(boolean[][] grid) {
        final long FNV_OFFSET_BASIS = 2166136261L;
        final long FNV_PRIME = 16777619L;

        long hasher = FNV_OFFSET_BASIS;
        for (int i = 0; i < grid.length; i++) {
            boolean[] row = grid[i];
            for (int j = 0; j < row.length; j++) {
                if (row[j]) {
                    long jSquared = (long) j * j;
                    hasher = (hasher ^ jSquared) * FNV_PRIME;
                }
            }
        }
        return hasher;
    }

    @Override
    public void run(int iterationId) {
        boolGrid = Maze.generateWalkableMaze(width, height);
    }

    @Override
    public long checksum() {
        return gridChecksum(boolGrid);
    }
}