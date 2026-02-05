package benchmarks;

import java.util.*;

public class AStarPathfinder extends Benchmark {
    private static final int INF = Integer.MAX_VALUE;
    private static final int STRAIGHT_COST = 1000;

    private static class Node implements Comparable<Node> {
        int x;
        int y;
        int fScore;

        Node(int x, int y, int fScore) {
            this.x = x;
            this.y = y;
            this.fScore = fScore;
        }

        @Override
        public int compareTo(Node other) {
            if (fScore != other.fScore) {
                return Integer.compare(fScore, other.fScore);
            }
            if (y != other.y) {
                return Integer.compare(y, other.y);
            }
            return Integer.compare(x, other.x);
        }
    }

    private long resultVal;
    private final int startX;
    private final int startY;
    private final int goalX;
    private final int goalY;
    private final int width;
    private final int height;
    private boolean[][] mazeGrid;

    private int[] gScoresFlat;      
    private int[] cameFromFlat;     

    public AStarPathfinder() {
        this.width = (int) configVal("w");
        this.height = (int) configVal("h");
        this.startX = 1;
        this.startY = 1;
        this.goalX = width - 2;
        this.goalY = height - 2;
        this.resultVal = 0L;
    }

    @Override
    public String name() {
        return "AStarPathfinder";
    }

    private int heuristic(int aX, int aY, int bX, int bY) {
        return Math.abs(aX - bX) + Math.abs(aY - bY);
    }

    private int packCoords(int x, int y) {
        return y * width + x;
    }

    private int[] unpackCoords(int idx) {
        return new int[]{idx % width, idx / width};
    }

    private Pair<Optional<List<int[]>>, Integer> findPath() {
        boolean[][] grid = mazeGrid;
        int size = width * height;
        int startIdx = packCoords(startX, startY);
        int goalIdx = packCoords(goalX, goalY);

        Arrays.fill(gScoresFlat, INF);
        Arrays.fill(cameFromFlat, -1);

        PriorityQueue<Node> openSet = new PriorityQueue<>();

        gScoresFlat[startIdx] = 0;
        openSet.add(new Node(startX, startY, 
                           heuristic(startX, startY, goalX, goalY)));

        int nodesExplored = 0;
        int[][] directions = {{0, -1}, {1, 0}, {0, 1}, {-1, 0}};

        while (!openSet.isEmpty()) {
            Node current = openSet.poll();
            nodesExplored++;

            if (current.x == goalX && current.y == goalY) {

                List<int[]> path = new ArrayList<>();
                int x = current.x;
                int y = current.y;

                while (x != startX || y != startY) {
                    path.add(new int[]{x, y});
                    int idx = packCoords(x, y);
                    int packed = cameFromFlat[idx];
                    if (packed == -1) break;

                    int[] prev = unpackCoords(packed);
                    x = prev[0];
                    y = prev[1];
                }

                path.add(new int[]{startX, startY});
                Collections.reverse(path);
                return new Pair<>(Optional.of(path), nodesExplored);
            }

            int currentIdx = packCoords(current.x, current.y);
            int currentG = gScoresFlat[currentIdx];

            for (int[] dir : directions) {
                int nx = current.x + dir[0];
                int ny = current.y + dir[1];

                if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;
                if (!grid[ny][nx]) continue;

                int tentativeG = currentG + STRAIGHT_COST;
                int neighborIdx = packCoords(nx, ny);

                if (tentativeG < gScoresFlat[neighborIdx]) {
                    cameFromFlat[neighborIdx] = currentIdx;
                    gScoresFlat[neighborIdx] = tentativeG;

                    int fScore = tentativeG + heuristic(nx, ny, goalX, goalY);
                    openSet.add(new Node(nx, ny, fScore));
                }
            }
        }

        return new Pair<>(Optional.empty(), nodesExplored);
    }

    private static class Pair<A, B> {
        final A first;
        final B second;
        Pair(A first, B second) {
            this.first = first;
            this.second = second;
        }
    }

    @Override
    public void prepare() {
        mazeGrid = MazeGenerator.Maze.generateWalkableMaze(width, height);

        int size = width * height;
        gScoresFlat = new int[size];
        cameFromFlat = new int[size];
    }

    @Override
    public void run(int iterationId) {
        Pair<Optional<List<int[]>>, Integer> result = findPath();

        long localResult = 0;
        if (result.first.isPresent()) {
            localResult = (localResult << 5) + result.first.get().size();
        }
        localResult = (localResult << 5) + result.second;
        resultVal += localResult;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}