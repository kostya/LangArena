package benchmarks;

public class Binarytrees extends Benchmark {
    private int n;
    private long resultVal;

    static class TreeNode {
        final int item;
        final TreeNode left;
        final TreeNode right;

        TreeNode(int item, int depth) {
            this.item = item;
            if (depth > 0) {
                left = new TreeNode(2 * item - 1, depth - 1);
                right = new TreeNode(2 * item, depth - 1);
            } else {
                left = null;
                right = null;
            }
        }

        int check() {
            if (left == null) {
                return item;
            } else {
                return left.check() - right.check() + item;
            }
        }

        static TreeNode create(int item, int depth) {
            return new TreeNode(item, depth - 1);
        }
    }

    public Binarytrees() {
        n = (int) configVal("depth");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Binarytrees";
    }

    @Override
    public void run(int iterationId) {
        int minDepth = 4;
        int maxDepth = Math.max(minDepth + 2, n);
        int stretchDepth = maxDepth + 1;

        resultVal += TreeNode.create(0, stretchDepth).check();

        for (int depth = minDepth; depth <= maxDepth; depth += 2) {
            int iterations = 1 << (maxDepth - depth + minDepth);

            for (int i = 1; i <= iterations; i++) {
                resultVal += TreeNode.create(i, depth).check();
                resultVal += TreeNode.create(-i, depth).check();
            }
        }
    }

    @Override
    public long checksum() {
        return resultVal & 0xFFFFFFFFL;
    }
}