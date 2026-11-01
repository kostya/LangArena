mutable struct BinarytreesObj <: AbstractBenchmark
    n::Int64
    result::UInt32
end

function BinarytreesObj()
    n = Helper.config_i64("Binarytrees::Obj", "depth")
    return BinarytreesObj(n, UInt32(0))
end

name(b::BinarytreesObj)::String = "Binarytrees::Obj"

mutable struct TreeNodeObj
    left::Union{Nothing,TreeNodeObj}
    right::Union{Nothing,TreeNodeObj}
    item::Int32

    function TreeNodeObj(item::Int32, depth::Int32)
        node = new(nothing, nothing, item)
        if depth > 0
            shift = Int32(1) << (depth - Int32(1))
            node.left = TreeNodeObj(item - shift, depth - Int32(1))
            node.right = TreeNodeObj(item + shift, depth - Int32(1))
        end
        return node
    end
end

function sum(node::TreeNodeObj)::Int32
    total = node.item + Int32(1)

    if node.left !== nothing
        total += sum(node.left)
    end
    if node.right !== nothing
        total += sum(node.right)
    end
    return total
end

function run(b::BinarytreesObj, iteration_id::Int64)
    tree = TreeNodeObj(Int32(0), Int32(b.n))
    b.result += sum(tree)
end

checksum(b::BinarytreesObj)::UInt32 = b.result

struct TreeNodeArena
    item::Int32
    left::Int32
    right::Int32
end

TreeNodeArena(item::Int32) = TreeNodeArena(item, Int32(-1), Int32(-1))

mutable struct BinarytreesArena <: AbstractBenchmark
    n::Int64
    result::UInt32
end

function BinarytreesArena()
    n = Helper.config_i64("Binarytrees::Arena", "depth")
    return BinarytreesArena(n, UInt32(0))
end

name(b::BinarytreesArena)::String = "Binarytrees::Arena"

function build!(nodes::Vector{TreeNodeArena}, item::Int32, depth::Int32)::Int32
    idx = Int32(length(nodes) + 1)
    push!(nodes, TreeNodeArena(item))

    if depth > 0
        shift = Int32(1) << (depth - Int32(1))
        left_idx = build!(nodes, item - shift, depth - Int32(1))
        right_idx = build!(nodes, item + shift, depth - Int32(1))

        nodes[Int(idx)] = TreeNodeArena(item, left_idx, right_idx)
    end

    return idx
end

function tree_sum(nodes::Vector{TreeNodeArena}, idx::Int32)::Int32
    node = nodes[idx]
    total = node.item + Int32(1)

    if node.left >= 1
        total += tree_sum(nodes, node.left)
    end
    if node.right >= 1
        total += tree_sum(nodes, node.right)
    end

    return total
end

function run(b::BinarytreesArena, iteration_id::Int64)
    nodes = TreeNodeArena[]
    root_idx = build!(nodes, Int32(0), Int32(b.n))
    b.result += tree_sum(nodes, root_idx)
end

checksum(b::BinarytreesArena)::UInt32 = b.result