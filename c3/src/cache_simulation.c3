module cache_simulation;

import benchmark;
import helper;
import std::io;
import std::collections::map;

struct CacheNode
{
	String key;
	String value;
	long timestamp;
	CacheNode* prev;
	CacheNode* next;
}

struct CacheSimulationCache
{
	CacheNode* head;
	CacheNode* tail;
	HashMap{String, CacheNode*} hash_table;
	usz capacity;
	usz size;
	long time;
}

fn CacheSimulationCache* cache_new(usz capacity)
{
	CacheSimulationCache* cache = mem::new(CacheSimulationCache);
	cache.capacity = capacity;
	cache.hash_table.init(mem);
	return cache;
}

fn void cache_move_to_front(CacheSimulationCache* cache, CacheNode* node)
{
	if (node == cache.head) return;

	if (node.prev)
	{
		node.prev.next = node.next;
	}
	if (node.next)
	{
		node.next.prev = node.prev;
	}
	if (node == cache.tail)
	{
		cache.tail = node.prev;
	}

	node.prev = null;
	node.next = cache.head;
	if (cache.head)
	{
		cache.head.prev = node;
	}
	cache.head = node;
	if (!cache.tail)
	{
		cache.tail = node;
	}
}

fn CacheNode* cache_get(CacheSimulationCache* cache, String key)
{
	CacheNode*? node_opt = cache.hash_table.get(key);
	if (catch node_opt) return null;

	cache_move_to_front(cache, node_opt);
	node_opt.timestamp = ++cache.time;
	return node_opt;
}

fn void cache_remove_oldest(CacheSimulationCache* cache)
{
	if (!cache.tail) return;

	CacheNode* oldest = cache.tail;
	cache.hash_table.remove(oldest.key);

	if (oldest.prev)
	{
		oldest.prev.next = oldest.next;
	}
	if (oldest.next)
	{
		oldest.next.prev = oldest.prev;
	}
	if (cache.head == oldest)
	{
		cache.head = oldest.next;
	}
	if (cache.tail == oldest)
	{
		cache.tail = oldest.prev;
	}

	free(oldest.key);
	free(oldest.value);
	free(oldest);
	cache.size--;
}

fn void cache_put(CacheSimulationCache* cache, String key, String value)
{
	CacheNode*? node_opt = cache.hash_table.get(key);
	if (try node = node_opt)
	{
		free(node.value);
		node.value = value.copy(mem);
		cache_move_to_front(cache, node);
		node.timestamp = ++cache.time;
		return;
	}

	if (cache.size >= cache.capacity)
	{
		cache_remove_oldest(cache);
	}

	CacheNode* node = mem::new(CacheNode);
	defer catch free(node);

	node.key = key.copy(mem);
	defer catch free(node.key);

	node.value = value.copy(mem);
	defer catch free(node.value);

	node.timestamp = ++cache.time;

	cache.hash_table.set(node.key, node);

	node.next = cache.head;
	if (cache.head)
	{
		cache.head.prev = node;
	}
	cache.head = node;
	if (!cache.tail)
	{
		cache.tail = node;
	}
	cache.size++;
}

fn void cache_free(CacheSimulationCache* cache)
{
	if (!cache) return;

	CacheNode* node = cache.head;
	while (node)
	{
		CacheNode* next = node.next;
		free(node.key);
		free(node.value);
		free(node);
		node = next;
	}

	cache.hash_table.free();
	free(cache);
}

struct CacheSimulationData
{
	uint result_val;
	long values_size;
	long cache_size;
	long hits;
	long misses;
	CacheSimulationCache* cache;
}

fn void cache_simulation_prepare(Benchmark* self)
{
	CacheSimulationData* data = (CacheSimulationData*)self.data;

	data.values_size = helper::helper_config_i64(self.name, "values");
	if (data.values_size <= 0)
	{
		data.values_size = 2000;
	}

	data.cache_size = helper::helper_config_i64(self.name, "size");
	if (data.cache_size <= 0)
	{
		data.cache_size = 1000;
	}

	data.result_val = 5432;
	data.cache = cache_new((usz)data.cache_size);
}

fn void cache_simulation_run(Benchmark* self, int iteration_id)
{
	CacheSimulationData* data = (CacheSimulationData*)self.data;

	for (int i = 0; i < 1000; i++)
	{
		char[32] key_buf;
		String key = string::bformat(key_buf[:32], "item_%d", helper::helper_next_int((uint)data.values_size));

		if (cache_get(data.cache, key))
		{
			data.hits++;
			char[32] val_buf;
			String value = string::bformat(val_buf[:32], "updated_%d", iteration_id);
			cache_put(data.cache, key, value);
		}
		else
		{
			data.misses++;
			char[32] val_buf;
			String value = string::bformat(val_buf[:32], "new_%d", iteration_id);
			cache_put(data.cache, key, value);
		}
	}
}

fn uint cache_simulation_checksum(Benchmark* self)
{
	CacheSimulationData* data = (CacheSimulationData*)self.data;

	uint final_result = data.result_val;
	final_result = (final_result << 5) + (uint)data.hits;
	final_result = (final_result << 5) + (uint)data.misses;
	final_result = (final_result << 5) + (uint)data.cache.size;

	return final_result;
}

fn void cache_simulation_cleanup(Benchmark* self)
{
	CacheSimulationData* data = (CacheSimulationData*)self.data;
	if (data.cache)
	{
		cache_free(data.cache);
		data.cache = null;
	}
}

fn Benchmark* cache_simulation_create() @cname("CacheSimulation_create") @export
{
	Benchmark* bench = benchmark::benchmark_create("Etc::CacheSimulation");

	CacheSimulationData* data = mem::new(CacheSimulationData);
	data.result_val = 5432;

	bench.data = data;
	bench.prepare = (PrepareFn)&cache_simulation_prepare;
	bench.run = (RunFn)&cache_simulation_run;
	bench.checksum = (ChecksumFn)&cache_simulation_checksum;
	bench.cleanup = (CleanupFn)&cache_simulation_cleanup;

	return bench;
}