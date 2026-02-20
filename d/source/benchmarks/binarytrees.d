module benchmarks.binarytrees;

import benchmark;
import helper;
import std.algorithm;
import std.stdio;

class Binarytrees : Benchmark
{
private:
    class TreeNode
    {
        TreeNode left;
        TreeNode right;
        int item;

        this(int item, int depth = 0)
        {
            this.item = item;
            if (depth > 0)
            {
                left = new TreeNode(2 * item - 1, depth - 1);
                right = new TreeNode(2 * item, depth - 1);
            }
        }

        int check() const
        {
            if (left is null || right is null)
                return item;
            return left.check() - right.check() + item;
        }
    }

    int n;
    uint resultVal;

public:
    this()
    {
        n = configVal("depth");
        resultVal = 0;
    }

    override string className() const
    {
        return "Binarytrees";
    }

    override void run(int iterationId)
    {
        int minDepth = 4;
        int maxDepth = max(minDepth + 2, n);
        int stretchDepth = maxDepth + 1;

        auto stretchTree = new TreeNode(0, stretchDepth);
        resultVal += cast(uint) stretchTree.check();

        for (int depth = minDepth; depth <= maxDepth; depth += 2)
        {
            int iterations = 1 << (maxDepth - depth + minDepth);
            for (int i = 1; i <= iterations; i++)
            {
                auto tree1 = new TreeNode(i, depth);
                auto tree2 = new TreeNode(-i, depth);
                resultVal += cast(uint) tree1.check();
                resultVal += cast(uint) tree2.check();
            }
        }
    }

    override uint checksum()
    {
        return resultVal;
    }
}
