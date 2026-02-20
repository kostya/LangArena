module binarytrees

import benchmark
import helper
import math

struct TreeNode {
mut:
	left  ?&TreeNode
	right ?&TreeNode
	item  int
}

fn new_tree_node(item int, depth int) &TreeNode {
	mut node := &TreeNode{
		item: item
	}

	if depth > 0 {
		node.left = new_tree_node(2 * item - 1, depth - 1)
		node.right = new_tree_node(2 * item, depth - 1)
	}

	return node
}

fn (t &TreeNode) check() int {
	if t.left == none || t.right == none {
		return t.item
	}

	left_check := unsafe { (t.left or { return t.item }).check() }
	right_check := unsafe { (t.right or { return t.item }).check() }

	return left_check - right_check + t.item
}

pub struct BinarytreesBenchmark {
	benchmark.BaseBenchmark
	n i64
mut:
	result_val u32
}

pub fn new_binarytrees() &benchmark.IBenchmark {
	mut bench := &BinarytreesBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark('Binarytrees')
		n:             helper.config_i64('Binarytrees', 'depth')
	}
	return bench
}

pub fn (b BinarytreesBenchmark) name() string {
	return 'Binarytrees'
}

pub fn (mut b BinarytreesBenchmark) run(iteration_id int) {
	_ = iteration_id

	min_depth := 4
	max_depth := int(math.max(f64(min_depth + 2), f64(b.n)))
	stretch_depth := max_depth + 1

	stretch_tree := new_tree_node(0, stretch_depth)
	b.result_val += u32(stretch_tree.check())

	for depth in min_depth .. max_depth + 1 {
		if depth % 2 != 0 {
			continue
		}

		iterations := 1 << (max_depth - depth + min_depth)
		for i in 1 .. iterations + 1 {
			tree1 := new_tree_node(i, depth)
			tree2 := new_tree_node(-i, depth)
			b.result_val += u32(tree1.check())
			b.result_val += u32(tree2.check())
		}
	}
}

pub fn (b BinarytreesBenchmark) checksum() u32 {
	return b.result_val
}

pub fn (mut b BinarytreesBenchmark) prepare() {
	b.result_val = 0
}
