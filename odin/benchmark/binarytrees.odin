package benchmark

import "core:fmt"
import "core:math"
import "core:mem"
import "core:mem/virtual"

TreeNodeObj :: struct {
	left:  ^TreeNodeObj,
	right: ^TreeNodeObj,
	item:  i32,
}

tree_node_obj_create :: proc(
	item: i32,
	depth: int,
	allocator := context.allocator,
) -> ^TreeNodeObj {
	node := new(TreeNodeObj, allocator)
	node.item = item

	if depth > 0 {
		shift := 1 << uint(depth - 1)
		node.left = tree_node_obj_create(item - i32(shift), depth - 1, allocator)
		node.right = tree_node_obj_create(item + i32(shift), depth - 1, allocator)
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

BinarytreesObj :: struct {
	using base: Benchmark,
	depth:      int,
	result_val: u32,
}

binarytrees_obj_run :: proc(bench: ^Benchmark, iteration_id: int) {
	bt := cast(^BinarytreesObj)bench

	arena: virtual.Arena
	err := virtual.arena_init_growing(&arena)
	if err != nil {

		return
	}
	defer virtual.arena_destroy(&arena)

	arena_alloc := virtual.arena_allocator(&arena)

	root := tree_node_obj_create(0, bt.depth, arena_alloc)

	bt.result_val += tree_node_obj_sum(root)

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
	bt.name = "Binarytrees::Obj"
	bt.vtable = default_vtable()
	bt.vtable.run = binarytrees_obj_run
	bt.vtable.checksum = binarytrees_obj_checksum
	bt.vtable.prepare = binarytrees_obj_prepare

	return cast(^Benchmark)bt
}

TreeNodeArena :: struct {
	item:  i32,
	left:  i32,
	right: i32,
}

BinarytreesArena :: struct {
	using base: Benchmark,
	depth:      int,
	result_val: u32,
	arena:      [dynamic]TreeNodeArena,
}

binarytrees_arena_build :: proc(bt: ^BinarytreesArena, item: i32, depth: i32) -> i32 {
	arena := &bt.arena
	idx := i32(len(arena))
	append(arena, TreeNodeArena{item = item, left = -1, right = -1})

	if depth > 0 {
		shift := i32(1) << uint(depth - 1)
		left_idx := binarytrees_arena_build(bt, item - shift, depth - 1)
		right_idx := binarytrees_arena_build(bt, item + shift, depth - 1)
		arena[idx].left = left_idx
		arena[idx].right = right_idx
	}

	return idx
}

binarytrees_arena_sum :: proc(bt: ^BinarytreesArena, idx: i32) -> u32 {
	node := bt.arena[idx]
	total := u32(node.item) + 1

	if node.left >= 0 {
		total += binarytrees_arena_sum(bt, node.left)
	}
	if node.right >= 0 {
		total += binarytrees_arena_sum(bt, node.right)
	}

	return total
}

binarytrees_arena_run :: proc(bench: ^Benchmark, iteration_id: int) {
	bt := cast(^BinarytreesArena)bench

	delete(bt.arena)
	bt.arena = make([dynamic]TreeNodeArena)
	root_idx := binarytrees_arena_build(bt, 0, i32(bt.depth))
	bt.result_val += binarytrees_arena_sum(bt, root_idx)
}

binarytrees_arena_checksum :: proc(bench: ^Benchmark) -> u32 {
	bt := cast(^BinarytreesArena)bench
	return bt.result_val
}

binarytrees_arena_prepare :: proc(bench: ^Benchmark) {
	bt := cast(^BinarytreesArena)bench
	bt.depth = int(config_i64(bt.name, "depth"))
	bt.result_val = 0
	bt.arena = make([dynamic]TreeNodeArena)
}

binarytrees_arena_cleanup :: proc(bench: ^Benchmark) {
	bt := cast(^BinarytreesArena)bench
	delete(bt.arena)
}

create_binarytrees_arena :: proc() -> ^Benchmark {
	bt := new(BinarytreesArena)
	bt.name = "Binarytrees::Arena"
	bt.vtable = default_vtable()
	bt.vtable.run = binarytrees_arena_run
	bt.vtable.checksum = binarytrees_arena_checksum
	bt.vtable.prepare = binarytrees_arena_prepare
	bt.vtable.cleanup = binarytrees_arena_cleanup

	return cast(^Benchmark)bt
}
