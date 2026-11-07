module binarytrees;

import benchmark;
import helper;
import std::collections::list;

struct TreeNodeObj
{
	TreeNodeObj* left;
	TreeNodeObj* right;
	int item;
}

fn TreeNodeObj* tree_node_new(int item, int depth)
{
	TreeNodeObj* node = mem::tnew(TreeNodeObj);
	node.item = item;

	if (depth > 0)
	{
		int shift = 1 << (depth - 1);
		node.left = tree_node_new(item - shift, depth - 1);
		node.right = tree_node_new(item + shift, depth - 1);
	}

	return node;
}

fn uint tree_node_sum(TreeNodeObj* node)
{
	uint total = (uint)node.item + 1;
	if (node.left) total += tree_node_sum(node.left);
	if (node.right) total += tree_node_sum(node.right);
	return total;
}

struct BinarytreesObjData
{
	long n;
	uint result_val;
}

fn void binarytrees_obj_prepare(Benchmark* self)
{
	BinarytreesObjData* data = (BinarytreesObjData*)self.data;
	data.n = helper::helper_config_i64(self.name, "depth");
}

fn void binarytrees_obj_run(Benchmark* self, int iteration_id)
{
	BinarytreesObjData* data = (BinarytreesObjData*)self.data;

	@pool()
	{
		TreeNodeObj* root = tree_node_new(0, (int)data.n);
		data.result_val += tree_node_sum(root);
	};
}

fn uint binarytrees_obj_checksum(Benchmark* self)
{
	BinarytreesObjData* data = (BinarytreesObjData*)self.data;
	return data.result_val;
}

fn void binarytrees_obj_cleanup(Benchmark* self)
{
	BinarytreesObjData* data = (BinarytreesObjData*)self.data;
	free(data);
	self.data = null;
}

fn Benchmark* binarytrees_obj_create() @cname("BinarytreesObj_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Binarytrees::Obj");

	BinarytreesObjData* data = mem::new(BinarytreesObjData);

	bench.data = data;
	bench.prepare = (PrepareFn)&binarytrees_obj_prepare;
	bench.run = (RunFn)&binarytrees_obj_run;
	bench.checksum = (ChecksumFn)&binarytrees_obj_checksum;
	bench.cleanup = (CleanupFn)&binarytrees_obj_cleanup;

	return bench;
}

struct ArenaNode
{
	int item;
	int left;
	int right;
}

struct Arena
{
	List{ArenaNode} nodes;
}

fn Arena* arena_new()
{
	Arena* arena = mem::new(Arena);
	arena.nodes.init(mem);
	return arena;
}

fn void arena_free(Arena* arena)
{
	if (arena)
	{
		arena.nodes.free();
		free(arena);
	}
}

fn int arena_build_tree(Arena* arena, int item, int depth)
{
	ArenaNode node = { .item = item, .left = -1, .right = -1 };
	arena.nodes.push(node);
	int idx = (int)arena.nodes.len() - 1;

	if (depth > 0)
	{
		int shift     = 1 << (depth - 1);
		int left_idx  = arena_build_tree(arena, item - shift, depth - 1);
		int right_idx = arena_build_tree(arena, item + shift, depth - 1);

		if (left_idx >= 0 && right_idx >= 0)
		{
			arena.nodes[idx].left = left_idx;
			arena.nodes[idx].right = right_idx;
		}
	}

	return idx;
}

fn uint arena_sum(Arena* arena, int idx)
{
	if (!arena || idx < 0 || idx >= arena.nodes.len()) return 0;

	ArenaNode* node = &arena.nodes[idx];
	uint total      = (uint)node.item + 1;

	if (node.left >= 0) total += arena_sum(arena, node.left);
	if (node.right >= 0) total += arena_sum(arena, node.right);

	return total;
}

struct BinarytreesArenaData
{
	long n;
	uint result_val;
	Arena* arena;
}

fn void binarytrees_arena_prepare(Benchmark* self)
{
	BinarytreesArenaData* data = (BinarytreesArenaData*)self.data;
	data.n = helper::helper_config_i64(self.name, "depth");
}

fn void binarytrees_arena_run(Benchmark* self, int iteration_id)
{
	BinarytreesArenaData* data = (BinarytreesArenaData*)self.data;

	data.arena = arena_new();

	int root_idx = arena_build_tree(data.arena, 0, (int)data.n);
	if (root_idx >= 0)
	{
		data.result_val += arena_sum(data.arena, root_idx);
	}

	arena_free(data.arena);
	data.arena = null;
}

fn uint binarytrees_arena_checksum(Benchmark* self)
{
	BinarytreesArenaData* data = (BinarytreesArenaData*)self.data;
	return data.result_val;
}

fn void binarytrees_arena_cleanup(Benchmark* self)
{
	BinarytreesArenaData* data = (BinarytreesArenaData*)self.data;
	arena_free(data.arena);
	free(data);
	self.data = null;
}

fn Benchmark* binarytrees_arena_create() @cname("BinarytreesArena_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Binarytrees::Arena");

	BinarytreesArenaData* data = mem::new(BinarytreesArenaData);

	bench.data = data;
	bench.prepare = (PrepareFn)&binarytrees_arena_prepare;
	bench.run = (RunFn)&binarytrees_arena_run;
	bench.checksum = (ChecksumFn)&binarytrees_arena_checksum;
	bench.cleanup = (CleanupFn)&binarytrees_arena_cleanup;

	return bench;
}