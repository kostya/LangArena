mutable struct BinarytreesObj <: AbstractBenchmark
    n::Int64
    result::UInt32
end

function BinarytreesObj()
    n = Helper.config_i64("BinarytreesObj", "depth")
    return BinarytreesObj(n, UInt32(0))
end

name(b::BinarytreesObj)::String = "BinarytreesObj"

mutable struct TreeNodeObj
    left::Union{Nothing,TreeNodeObj}
    right::Union{Nothing,TreeNodeObj}
    item::Int64

    function TreeNodeObj(item::Int64, depth::Int64)
        node = new(nothing, nothing, item)
        if depth > 0
            shift = 1 << (depth - 1)
            node.left = TreeNodeObj(item - shift, depth - 1)
            node.right = TreeNodeObj(item + shift, depth - 1)
        end
        return node
    end
end

function sum(node::TreeNodeObj)::Int64
    total = node.item + 1

    if node.left !== nothing
        total += sum(node.left)
    end
    if node.right !== nothing
        total += sum(node.right)
    end
    return total
end

function run(b::BinarytreesObj, iteration_id::Int64)
    tree = TreeNodeObj(0, b.n)
    b.result += Helper.to_u32(sum(tree))

end

checksum(b::BinarytreesObj)::UInt32 = b.result

mutable struct TreeNodeArena
    item::Int64
    left::Int64
    right::Int64

    function TreeNodeArena(item::Int64)
        return new(item, -1, -1)
    end
end

mutable struct BinarytreesArena <: AbstractBenchmark
    n::Int64
    result::UInt32

end

function BinarytreesArena()
    n = Helper.config_i64("BinarytreesArena", "depth")
    return BinarytreesArena(n, UInt32(0))
end

name(b::BinarytreesArena)::String = "BinarytreesArena"

function build!(nodes::Vector{TreeNodeArena}, item::Int64, depth::Int64)::Int64
    idx = length(nodes) + 1
    push!(nodes, TreeNodeArena(item))

    if depth > 0
        shift = 1 << (depth - 1)
        left_idx = build!(nodes, item - shift, depth - 1)
        right_idx = build!(nodes, item + shift, depth - 1)
        nodes[idx].left = left_idx
        nodes[idx].right = right_idx
    end

    return idx
end

function sum(nodes::Vector{TreeNodeArena}, idx::Int64)::Int64
    node = nodes[idx]
    total = node.item + 1

    if node.left >= 1
        total += sum(nodes, node.left)
    end
    if node.right >= 1
        total += sum(nodes, node.right)
    end

    return total
end

function run(b::BinarytreesArena, iteration_id::Int64)

    nodes = TreeNodeArena[]
    root_idx = build!(nodes, 0, b.n)
    b.result += Helper.to_u32(sum(nodes, root_idx))

end

checksum(b::BinarytreesArena)::UInt32 = b.result
