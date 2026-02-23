module benchmarks.binarytrees;

import benchmark;
import helper;
import std.algorithm;
import std.stdio;
import std.array;

class BinarytreesObj : Benchmark
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
                int shift = 1 << (depth - 1);
                left = new TreeNode(item - shift, depth - 1);
                right = new TreeNode(item + shift, depth - 1);
            }
        }

        uint sum() const
        {
            uint total = cast(uint) item + 1;
            if (left !is null)
                total += left.sum();
            if (right !is null)
                total += right.sum();
            return total;
        }
    }

    int n;
    uint resultVal;

public:
    this()
    {
        n = cast(int) configVal("depth");
        resultVal = 0;
    }

    override string className() const
    {
        return "Binarytrees::Obj";
    }

    override void run(int iterationId)
    {
        auto root = new TreeNode(0, n);
        resultVal += root.sum();

    }

    override uint checksum()
    {
        return resultVal;
    }
}

class BinarytreesArena : Benchmark
{
private:
    struct TreeNode
    {
        int item;
        int left = -1;
        int right = -1;
    }

    class TreeArena
    {
        TreeNode[] nodes;

        this()
        {
        }

        int build(int item, int depth)
        {
            int idx = cast(int) nodes.length;
            nodes ~= TreeNode(item);

            if (depth > 0)
            {
                int shift = 1 << (depth - 1);
                int leftIdx = build(item - shift, depth - 1);
                int rightIdx = build(item + shift, depth - 1);
                nodes[idx].left = leftIdx;
                nodes[idx].right = rightIdx;
            }

            return idx;
        }

        uint sum(int idx) const
        {
            auto node = nodes[idx];
            uint total = cast(uint) node.item + 1;

            if (node.left >= 0)
                total += sum(node.left);
            if (node.right >= 0)
                total += sum(node.right);

            return total;
        }
    }

    int n;
    uint resultVal;

public:
    this()
    {
        n = cast(int) configVal("depth");
        resultVal = 0;
    }

    override string className() const
    {
        return "Binarytrees::Arena";
    }

    override void run(int iterationId)
    {
        TreeArena arena = new TreeArena();
        int rootIdx = arena.build(0, n);
        resultVal += arena.sum(rootIdx);
    }

    override uint checksum()
    {
        return resultVal;
    }
}
