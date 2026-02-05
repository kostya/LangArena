mutable struct Binarytrees <: AbstractBenchmark
    n::Int64
    result::UInt32
end

function Binarytrees()
    n = Helper.config_i64("Binarytrees", "depth")
    return Binarytrees(n, UInt32(0))
end

name(b::Binarytrees)::String = "Binarytrees"

mutable struct TreeNode
    left::Union{Nothing,TreeNode}
    right::Union{Nothing,TreeNode}
    item::Int64

    function TreeNode(item::Int64, depth::Int64)
        node = new(nothing, nothing, item)
        if depth > 0
            node.left = TreeNode(2 * item - 1, depth - 1)
            node.right = TreeNode(2 * item, depth - 1)
        end
        return node
    end
end

function check(node::TreeNode)::Int64
    if node.left === nothing || node.right === nothing
        return node.item
    end
    return check(node.left) - check(node.right) + node.item
end

function run(b::Binarytrees, iteration_id::Int64)
    min_depth = 4
    max_depth = max(min_depth + 2, b.n)
    stretch_depth = max_depth + 1

    local_result = Int64(0)

    stretch_tree = TreeNode(0, stretch_depth)
    local_result += check(stretch_tree)

    for depth in min_depth:2:max_depth
        iterations = 1 << (max_depth - depth + min_depth)
        for i in 1:iterations
            tree1 = TreeNode(i, depth)
            tree2 = TreeNode(-i, depth)
            local_result += check(tree1)
            local_result += check(tree2)
        end
    end

    b.result += Helper.to_u32(local_result)
end

checksum(b::Binarytrees)::UInt32 = b.result