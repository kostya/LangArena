package benchmark

import "core:fmt"
import "core:math"
import "core:mem/virtual"
import "core:mem"

TreeNodeObj :: struct {
    left:  ^TreeNodeObj,
    right: ^TreeNodeObj,
    item:  int,
}

tree_node_obj_create :: proc(item: int, depth: int, allocator := context.allocator) -> ^TreeNodeObj {
    node := new(TreeNodeObj, allocator)
    node.item = item

    if depth > 0 {
        shift := 1 << uint(depth - 1)
        node.left = tree_node_obj_create(item - int(shift), depth - 1, allocator)
        node.right = tree_node_obj_create(item + int(shift), depth - 1, allocator)
    } else {
        node.left = nil
        node.right = nil
    }

    return node
}

tree_node_obj_sum :: proc(node: ^TreeNodeObj) -> u32 {
    if node == nil {
        return 0
    }

    total := u32(node.item) + 1
    total += tree_node_obj_sum(node.left)
    total += tree_node_obj_sum(node.right)

    return total
}

tree_node_obj_destroy :: proc(node: ^TreeNodeObj, allocator := context.allocator) {
    if node == nil {
        return
    }

    tree_node_obj_destroy(node.left, allocator)
    tree_node_obj_destroy(node.right, allocator)
    free(node, allocator)
}

BinarytreesObj :: struct {
    using base: Benchmark,
    depth: int,
    result_val: u32,
}

binarytrees_obj_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bt := cast(^BinarytreesObj)bench

    tree := tree_node_obj_create(0, bt.depth)
    defer tree_node_obj_destroy(tree)

    bt.result_val += tree_node_obj_sum(tree)
}

binarytrees_obj_checksum :: proc(bench: ^Benchmark) -> u32 {
    bt := cast(^BinarytreesObj)bench
    return bt.result_val
}

binarytrees_obj_prepare :: proc(bench: ^Benchmark) {
    bt := cast(^BinarytreesObj)bench
    bt.depth = int(config_i64(bt.name, "depth"))
}

create_binarytrees_obj :: proc() -> ^Benchmark {
    bt := new(BinarytreesObj)
    bt.name = "BinarytreesObj"
    bt.vtable = default_vtable()
    bt.vtable.run = binarytrees_obj_run
    bt.vtable.checksum = binarytrees_obj_checksum
    bt.vtable.prepare = binarytrees_obj_prepare

    return cast(^Benchmark)bt
}

TreeNodeArena :: struct {
    item:  int,
    left:  ^TreeNodeArena,
    right: ^TreeNodeArena,
}

BinarytreesArena :: struct {
    using base: Benchmark,
    depth: int,
    result_val: u32,
}

tree_node_arena_create :: proc(arena_allocator: mem.Allocator, item: int, depth: int) -> ^TreeNodeArena {
    node := new(TreeNodeArena, arena_allocator)
    node.item = item

    if depth > 0 {
        shift := 1 << uint(depth - 1)
        node.left = tree_node_arena_create(arena_allocator, item - int(shift), depth - 1)
        node.right = tree_node_arena_create(arena_allocator, item + int(shift), depth - 1)
    } else {
        node.left = nil
        node.right = nil
    }

    return node
}

tree_node_arena_sum :: proc(node: ^TreeNodeArena) -> u32 {
    if node == nil {
        return 0
    }

    total := u32(node.item) + 1
    total += tree_node_arena_sum(node.left)
    total += tree_node_arena_sum(node.right)

    return total
}

binarytrees_arena_run :: proc(bench: ^Benchmark, iteration_id: int) {
    bt := cast(^BinarytreesArena)bench

    arena: virtual.Arena
    err := virtual.arena_init_growing(&arena)
    if err != nil {
        fmt.println("ERROR: failed to initialize arena")
        return
    }
    defer virtual.arena_destroy(&arena)  

    allocator := virtual.arena_allocator(&arena)

    tree := tree_node_arena_create(allocator, 0, bt.depth)
    bt.result_val += tree_node_arena_sum(tree)

}

binarytrees_arena_checksum :: proc(bench: ^Benchmark) -> u32 {
    bt := cast(^BinarytreesArena)bench
    return bt.result_val
}

binarytrees_arena_prepare :: proc(bench: ^Benchmark) {
    bt := cast(^BinarytreesArena)bench
    bt.depth = int(config_i64(bt.name, "depth"))
}

binarytrees_arena_cleanup :: proc(bench: ^Benchmark) {
    bt := cast(^BinarytreesArena)bench
}

create_binarytrees_arena :: proc() -> ^Benchmark {
    bt := new(BinarytreesArena)
    bt.name = "BinarytreesArena"
    bt.vtable = default_vtable()
    bt.vtable.run = binarytrees_arena_run
    bt.vtable.checksum = binarytrees_arena_checksum
    bt.vtable.prepare = binarytrees_arena_prepare
    bt.vtable.cleanup = binarytrees_arena_cleanup

    return cast(^Benchmark)bt
}