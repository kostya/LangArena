module binarytrees

import benchmark
import helper

struct TreeNode {
mut:
	left  &TreeNode = unsafe { nil }
	right &TreeNode = unsafe { nil }
	item  int
}

fn new_tree_node(item int, depth int) &TreeNode {
	mut node := &TreeNode{
		item: item
	}

	if depth > 0 {
		shift := 1 << (depth - 1)
		node.left = new_tree_node(item - shift, depth - 1)
		node.right = new_tree_node(item + shift, depth - 1)
	}

	return node
}

fn (t &TreeNode) sum() u32 {
	mut total := u32(t.item) + 1

	if !isnil(t.left) {
		total += t.left.sum()
	}
	if !isnil(t.right) {
		total += t.right.sum()
	}

	return total
}

pub struct BinarytreesObjBenchmark {
	benchmark.BaseBenchmark
	n i64
mut:
	result_val u32
}

pub fn new_binarytrees_obj() &benchmark.IBenchmark {
	mut bench := &BinarytreesObjBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark('Binarytrees::Obj')
		n:             helper.config_i64('Binarytrees::Obj', 'depth')
	}
	return bench
}

pub fn (b BinarytreesObjBenchmark) name() string {
	return 'Binarytrees::Obj'
}

pub fn (mut b BinarytreesObjBenchmark) run(iteration_id int) {
	tree := new_tree_node(0, int(b.n))
	b.result_val += tree.sum()
}

pub fn (b BinarytreesObjBenchmark) checksum() u32 {
	return b.result_val
}

pub fn (mut b BinarytreesObjBenchmark) prepare() {
	b.result_val = 0
}

struct TreeNodeArena {
	item int
mut:
	left  int = -1
	right int = -1
}

struct TreeArena {
mut:
	nodes []TreeNodeArena
}

fn new_tree_arena() &TreeArena {
	return &TreeArena{
		nodes: []TreeNodeArena{}
	}
}

fn (mut a TreeArena) build(item int, depth int) int {
	idx := a.nodes.len
	a.nodes << TreeNodeArena{
		item: item
	}

	if depth > 0 {
		shift := 1 << (depth - 1)
		left_idx := a.build(item - shift, depth - 1)
		right_idx := a.build(item + shift, depth - 1)
		mut node := &a.nodes[idx]
		node.left = left_idx
		node.right = right_idx
	}

	return idx
}

fn (a TreeArena) sum(idx int) u32 {
	node := a.nodes[idx]
	mut total := u32(node.item) + 1

	if node.left >= 0 {
		total += a.sum(node.left)
	}
	if node.right >= 0 {
		total += a.sum(node.right)
	}

	return total
}

pub struct BinarytreesArenaBenchmark {
	benchmark.BaseBenchmark
	n i64
mut:
	result_val u32
}

pub fn new_binarytrees_arena() &benchmark.IBenchmark {
	mut bench := &BinarytreesArenaBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark('Binarytrees::Arena')
		n:             helper.config_i64('Binarytrees::Arena', 'depth')
	}
	return bench
}

pub fn (b BinarytreesArenaBenchmark) name() string {
	return 'Binarytrees::Arena'
}

pub fn (mut b BinarytreesArenaBenchmark) run(iteration_id int) {
	mut arena := new_tree_arena()
	root_idx := arena.build(0, int(b.n))
	b.result_val += arena.sum(root_idx)
}

pub fn (b BinarytreesArenaBenchmark) checksum() u32 {
	return b.result_val
}

pub fn (mut b BinarytreesArenaBenchmark) prepare() {
	b.result_val = 0
}
