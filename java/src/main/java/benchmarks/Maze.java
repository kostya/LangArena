package benchmarks;

import java.util.*;

class MazeCellKind {
    public static final int WALL = 0;
    public static final int SPACE = 1;
    public static final int START = 2;
    public static final int FINISH = 3;
    public static final int BORDER = 4;
    public static final int PATH = 5;
}

class MazeCell {
    public int kind;
    public final MazeCell[] neighbors = new MazeCell[4];
    public int neighborCount;
    public final int x, y;

    public MazeCell(int x, int y) {
        this.kind = MazeCellKind.WALL;
        this.x = x;
        this.y = y;
        this.neighborCount = 0;
    }

    public void addNeighbor(MazeCell cell) {
        neighbors[neighborCount++] = cell;
    }

    public boolean isWalkable() {
        return kind == MazeCellKind.SPACE ||
               kind == MazeCellKind.START ||
               kind == MazeCellKind.FINISH;
    }

    public void reset() {
        if (kind == MazeCellKind.SPACE) {
            kind = MazeCellKind.WALL;
        }
    }
}

class Maze {
    private final int width, height;
    public final MazeCell[][] cells;
    private final MazeCell start, finish;
    private final Random random = new Random();

    public Maze(int w, int h) {
        this.width = w;
        this.height = h;
        this.cells = new MazeCell[height][width];

        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                cells[y][x] = new MazeCell(x, y);
            }
        }

        start = cells[1][1];
        finish = cells[height-2][width-2];
        start.kind = MazeCellKind.START;
        finish.kind = MazeCellKind.FINISH;

        updateNeighbors();
    }

    public void updateNeighbors() {
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                MazeCell cell = cells[y][x];
                cell.neighborCount = 0;

                if (x > 0 && y > 0 && x < width - 1 && y < height - 1) {
                    cell.addNeighbor(cells[y-1][x]);
                    cell.addNeighbor(cells[y+1][x]);
                    cell.addNeighbor(cells[y][x+1]);
                    cell.addNeighbor(cells[y][x-1]);

                    for (int t = 0; t < 4; t++) {
                        int i = Helper.nextInt(4);
                        int j = Helper.nextInt(4);
                        if (i != j) {
                            MazeCell temp = cell.neighbors[i];
                            cell.neighbors[i] = cell.neighbors[j];
                            cell.neighbors[j] = temp;
                        }
                    }
                } else {
                    cell.kind = MazeCellKind.BORDER;
                }
            }
        }
    }

    public void reset() {
        for (MazeCell[] row : cells) {
            for (MazeCell cell : row) {
                cell.reset();
            }
        }
        start.kind = MazeCellKind.START;
        finish.kind = MazeCellKind.FINISH;
    }

    public void dig(MazeCell startCell) {
        Deque<MazeCell> stack = new ArrayDeque<>();
        stack.push(startCell);

        while (!stack.isEmpty()) {
            MazeCell cell = stack.pop();

            int walkable = 0;
            for (int i = 0; i < cell.neighborCount; i++) {
                if (cell.neighbors[i].isWalkable()) walkable++;
            }

            if (walkable != 1) continue;

            cell.kind = MazeCellKind.SPACE;

            for (int i = 0; i < cell.neighborCount; i++) {
                MazeCell n = cell.neighbors[i];
                if (n.kind == MazeCellKind.WALL) {
                    stack.push(n);
                }
            }
        }
    }

    public void ensureOpenFinish(MazeCell startCell) {
        Deque<MazeCell> stack = new ArrayDeque<>();
        stack.push(startCell);

        while (!stack.isEmpty()) {
            MazeCell cell = stack.pop();

            cell.kind = MazeCellKind.SPACE;

            int walkable = 0;
            for (int i = 0; i < cell.neighborCount; i++) {
                if (cell.neighbors[i].isWalkable()) walkable++;
            }

            if (walkable > 1) continue;

            for (int i = 0; i < cell.neighborCount; i++) {
                MazeCell n = cell.neighbors[i];
                if (n.kind == MazeCellKind.WALL) {
                    stack.push(n);
                }
            }
        }
    }

    public void generate() {
        for (int i = 0; i < start.neighborCount; i++) {
            MazeCell n = start.neighbors[i];
            if (n.kind == MazeCellKind.WALL) {
                dig(n);
            }
        }

        for (int i = 0; i < finish.neighborCount; i++) {
            MazeCell n = finish.neighbors[i];
            if (n.kind == MazeCellKind.WALL) {
                ensureOpenFinish(n);
            }
        }
    }

    public MazeCell middleCell() {
        return cells[height/2][width/2];
    }

    public MazeCell getStart() {
        return start;
    }
    public MazeCell getFinish() {
        return finish;
    }

    public long checksum() {
        long hasher = 2166136261L;
        long prime = 16777619L;

        for (MazeCell[] row : cells) {
            for (MazeCell cell : row) {
                if (cell.kind == MazeCellKind.SPACE) {
                    long val = ((long)cell.x * cell.y) & 0xFFFFFFFFL;
                    hasher = ((hasher ^ val) * prime) & 0xFFFFFFFFL;
                }
            }
        }
        return hasher;
    }

    public void printToConsole() {
        for (MazeCell[] row : cells) {
            for (MazeCell cell : row) {
                switch (cell.kind) {
                case MazeCellKind.SPACE:
                    System.out.print(" ");
                    break;
                case MazeCellKind.WALL:
                    System.out.print("\u001B[34m#\u001B[0m");
                    break;
                case MazeCellKind.BORDER:
                    System.out.print("\u001B[31mO\u001B[0m");
                    break;
                case MazeCellKind.START:
                    System.out.print("\u001B[32m>\u001B[0m");
                    break;
                case MazeCellKind.FINISH:
                    System.out.print("\u001B[32m<\u001B[0m");
                    break;
                case MazeCellKind.PATH:
                    System.out.print("\u001B[33m.\u001B[0m");
                    break;
                }
            }
            System.out.println();
        }
        System.out.println();
    }
}

class MazeGenerator extends Benchmark {
    private long resultVal;
    private final int width, height;
    private final Maze maze;

    public MazeGenerator() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.maze = new Maze(width, height);
        this.resultVal = 0L;
    }

    @Override
    public String name() {
        return "Maze::Generator";
    }

    @Override
    public void prepare() {}

    @Override
    public void run(int iterationId) {
        maze.reset();
        maze.generate();
        resultVal = (resultVal + maze.middleCell().kind) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return (resultVal + maze.checksum()) & 0xFFFFFFFFL;
    }
}

class MazeBFS extends Benchmark {
    private long resultVal;
    private final int width, height;
    private final Maze maze;
    private List<MazeCell> path = new ArrayList<>();

    public MazeBFS() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.maze = new Maze(width, height);
        this.resultVal = 0L;
    }

    @Override
    public String name() {
        return "Maze::BFS";
    }

    @Override
    public void prepare() {
        maze.generate();
    }

    private static class PathNode {
        MazeCell cell;
        int parent;
        PathNode(MazeCell cell, int parent) {
            this.cell = cell;
            this.parent = parent;
        }
    }

    private List<MazeCell> bfs(MazeCell start, MazeCell target) {
        if (start == target) {
            return Arrays.asList(start);
        }

        Deque<Integer> queue = new ArrayDeque<>();
        boolean[][] visited = new boolean[height][width];
        List<PathNode> pathNodes = new ArrayList<>();

        visited[start.y][start.x] = true;
        pathNodes.add(new PathNode(start, -1));
        queue.add(0);

        while (!queue.isEmpty()) {
            int pathId = queue.poll();
            MazeCell cell = pathNodes.get(pathId).cell;

            for (int i = 0; i < cell.neighborCount; i++) {
                MazeCell neighbor = cell.neighbors[i];

                if (neighbor == target) {
                    List<MazeCell> result = new ArrayList<>();
                    result.add(target);
                    int current = pathId;
                    while (current >= 0) {
                        result.add(pathNodes.get(current).cell);
                        current = pathNodes.get(current).parent;
                    }
                    Collections.reverse(result);
                    return result;
                }

                if (neighbor.isWalkable() && !visited[neighbor.y][neighbor.x]) {
                    visited[neighbor.y][neighbor.x] = true;
                    pathNodes.add(new PathNode(neighbor, pathId));
                    queue.add(pathNodes.size() - 1);
                }
            }
        }

        return new ArrayList<>();
    }

    private long midCellChecksum(List<MazeCell> p) {
        if (p.isEmpty()) return 0;
        MazeCell cell = p.get(p.size() / 2);
        return ((long)cell.x * cell.y) & 0xFFFFFFFFL;
    }

    @Override
    public void run(int iterationId) {
        path = bfs(maze.getStart(), maze.getFinish());
        resultVal = (resultVal + path.size()) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return (resultVal + midCellChecksum(path)) & 0xFFFFFFFFL;
    }
}

class MazeAStar extends Benchmark {
    private static class PriorityQueueItem implements Comparable<PriorityQueueItem> {
        int priority;
        int vertex;

        PriorityQueueItem(int priority, int vertex) {
            this.priority = priority;
            this.vertex = vertex;
        }

        @Override
        public int compareTo(PriorityQueueItem other) {
            if (this.priority != other.priority)
                return Integer.compare(this.priority, other.priority);
            return Integer.compare(this.vertex, other.vertex);
        }
    }

    private long resultVal;
    private final int width, height;
    private final Maze maze;
    private List<MazeCell> path = new ArrayList<>();
    private final int[] bestF;

    public MazeAStar() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.maze = new Maze(width, height);
        this.resultVal = 0L;
        this.bestF = new int[width * height];
    }

    @Override
    public String name() {
        return "Maze::AStar";
    }

    @Override
    public void prepare() {
        maze.generate();
        Arrays.fill(bestF, Integer.MAX_VALUE);
    }

    private int heuristic(MazeCell a, MazeCell b) {
        return Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
    }

    private int idx(int y, int x) {
        return y * width + x;
    }

    private List<MazeCell> astar(MazeCell start, MazeCell target) {
        if (start == target) return Arrays.asList(start);

        int size = width * height;

        int[] cameFrom = new int[size];
        int[] gScore = new int[size];
        Arrays.fill(cameFrom, -1);
        Arrays.fill(gScore, Integer.MAX_VALUE);

        int startIdx = idx(start.y, start.x);
        int targetIdx = idx(target.y, target.x);

        PriorityQueue<PriorityQueueItem> openSet = new PriorityQueue<>();

        int[] bestF = new int[size];
        Arrays.fill(bestF, Integer.MAX_VALUE);

        gScore[startIdx] = 0;
        int fStart = heuristic(start, target);
        openSet.offer(new PriorityQueueItem(fStart, startIdx));
        bestF[startIdx] = fStart;

        while (!openSet.isEmpty()) {
            PriorityQueueItem item = openSet.poll();
            int currentIdx = item.vertex;

            if (item.priority != bestF[currentIdx]) continue;

            if (currentIdx == targetIdx) {
                List<MazeCell> result = new ArrayList<>();
                int cur = currentIdx;
                while (cur != -1) {
                    int y = cur / width;
                    int x = cur % width;
                    result.add(maze.cells[y][x]);
                    cur = cameFrom[cur];
                }
                Collections.reverse(result);
                return result;
            }

            int currentY = currentIdx / width;
            int currentX = currentIdx % width;
            MazeCell current = maze.cells[currentY][currentX];
            int currentG = gScore[currentIdx];

            for (int i = 0; i < current.neighborCount; i++) {
                MazeCell neighbor = current.neighbors[i];
                if (!neighbor.isWalkable()) continue;

                int neighborIdx = idx(neighbor.y, neighbor.x);
                int tentativeG = currentG + 1;

                if (tentativeG < gScore[neighborIdx]) {
                    cameFrom[neighborIdx] = currentIdx;
                    gScore[neighborIdx] = tentativeG;
                    int fNew = tentativeG + heuristic(neighbor, target);

                    if (fNew < bestF[neighborIdx]) {
                        bestF[neighborIdx] = fNew;
                        openSet.offer(new PriorityQueueItem(fNew, neighborIdx));
                    }
                }
            }
        }

        return new ArrayList<>();
    }

    private long midCellChecksum(List<MazeCell> p) {
        if (p.isEmpty()) return 0;
        MazeCell cell = p.get(p.size() / 2);
        return ((long)cell.x * cell.y) & 0xFFFFFFFFL;
    }

    @Override
    public void run(int iterationId) {
        path = astar(maze.getStart(), maze.getFinish());
        resultVal = (resultVal + path.size()) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return (resultVal + midCellChecksum(path)) & 0xFFFFFFFFL;
    }
}