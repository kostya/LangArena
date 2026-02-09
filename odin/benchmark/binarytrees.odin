package benchmark

import "core:fmt"
import "core:math"

TreeNode :: struct {
    left:  ^TreeNode,
    right: ^TreeNode,
    item:  int,
}

tree_node_create :: proc(item: int, depth: int, allocator := context.allocator) -> ^TreeNode {
    node := new(TreeNode, allocator)
    node.item = item

    if depth > 0 {
        node.left = tree_node_create(2 * item - 1, depth - 1, allocator)
        node.right = tree_node_create(2 * item, depth - 1, allocator)
    } else {
        node.left = nil
        node.right = nil
    }

    return node
}

tree_node_check :: proc(node: ^TreeNode) -> int {
    if node == nil {
        return 0
    }

    if node.left == nil || node.right == nil {
        return node.item
    }

    left_check := tree_node_check(node.left)
    right_check := tree_node_check(node.right)

    return left_check - right_check + node.item
}

tree_node_destroy :: proc(node: ^TreeNode, allocator := context.allocator) {
    if node == nil {
        return
    }

    tree_node_destroy(node.left, allocator)
    tree_node_destroy(node.right, allocator)

    free(node, allocator)
}

Binarytrees :: struct {
    using base: Benchmark,
    depth: int,
    result_val: u32,
}

binarytrees_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bt := cast(^Binarytrees)bench

    min_depth := 4
    max_depth := max(min_depth + 2, bt.depth)
    stretch_depth := max_depth + 1

    stretch_tree := tree_node_create(0, stretch_depth)
    defer tree_node_destroy(stretch_tree)
    bt.result_val += u32(tree_node_check(stretch_tree))

    for depth := min_depth; depth <= max_depth; depth += 2 {
        iterations := 1 << u32(max_depth - depth + min_depth)  

        for i := 1; i <= iterations; i += 1 {

            tree1 := tree_node_create(i, depth)
            defer tree_node_destroy(tree1)
            bt.result_val += u32(tree_node_check(tree1))

            tree2 := tree_node_create(-i, depth)
            defer tree_node_destroy(tree2)
            bt.result_val += u32(tree_node_check(tree2))
        }
    }
}

binarytrees_checksum :: proc(bench: ^Benchmark) -> u32 {
    bt := cast(^Binarytrees)bench
    return bt.result_val
}

binarytrees_prepare :: proc(bench: ^Benchmark) {
    bt := cast(^Binarytrees)bench
    bt.depth = int(config_i64(bt.name, "depth"))
}

binarytrees_cleanup :: proc(bench: ^Benchmark) {

}

create_binarytrees :: proc() -> ^Benchmark {
    bt := new(Binarytrees)
    bt.name = "Binarytrees"
    bt.vtable = default_vtable()
    bt.vtable.run = binarytrees_run
    bt.vtable.checksum = binarytrees_checksum
    bt.vtable.prepare = binarytrees_prepare

    return cast(^Benchmark)bt
}