package benchmarks;
import java.util.ArrayList;

class BinarytreesObj extends Benchmark {
    private int n;
    private long resultVal;

    static class TreeNode {
        final int item;
        final TreeNode left;
        final TreeNode right;

        TreeNode(int item, int depth) {
            this.item = item;
            if (depth > 0) {

                int shift = 1 << (depth - 1);
                left = new TreeNode(item - shift, depth - 1);
                right = new TreeNode(item + shift, depth - 1);
            } else {
                left = null;
                right = null;
            }
        }

        long sum() {
            long total = item + 1;

            if (left != null) {
                total += left.sum();
            }
            if (right != null) {
                total += right.sum();
            }

            return total;
        }
    }

    public BinarytreesObj() {
        n = (int) configVal("depth");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Binarytrees::Obj";
    }

    @Override
    public void run(int iterationId) {
        TreeNode root = new TreeNode(0, n);
        resultVal = resultVal + root.sum();
    }

    @Override
    public long checksum() {
        return resultVal & 0xFFFFFFFFL;
    }
}

class BinarytreesArena extends Benchmark {
    private static class TreeNode {
        final int item;
        int left;
        int right;

        TreeNode(int item) {
            this.item = item;
            this.left = -1;
            this.right = -1;
        }
    }

    private ArrayList<TreeNode> arena;
    private int n;
    private long resultVal;

    public BinarytreesArena() {
        this.n = (int) configVal("depth");
        this.arena = new ArrayList<>();
        this.resultVal = 0L;
    }

    private int buildTree(int item, int depth) {
        int idx = arena.size();
        arena.add(new TreeNode(item));

        if (depth > 0) {
            int leftIdx = buildTree(item - (1 << (depth - 1)), depth - 1);
            int rightIdx = buildTree(item + (1 << (depth - 1)), depth - 1);

            TreeNode node = arena.get(idx);
            node.left = leftIdx;
            node.right = rightIdx;

        }

        return idx;
    }

    private long sum(int idx) {
        TreeNode node = arena.get(idx);
        long total = (node.item & 0xFFFFFFFFL) + 1;

        if (node.left >= 0) {
            total += sum(node.left);
        }
        if (node.right >= 0) {
            total += sum(node.right);
        }

        return total & 0xFFFFFFFFL;
    }

    @Override
    public String name() {
        return "Binarytrees::Arena";
    }

    @Override
    public void run(int iterationId) {
        arena = new ArrayList<>();
        buildTree(0, n);
        resultVal = (resultVal + sum(0)) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return resultVal & 0xFFFFFFFFL;
    }
}