namespace cache_simulation;

import std;
import dictionary;
import bench;
import helper;

struct Node {
    key: u8[..16],
    value: u8[..32],
    prev: Node?,
    next: Node?,
}

fn new_node(key: u8[:], value: u8[:]) -> Node {
    return Node { key: key, value: value, prev: null, next: null };
}

struct LruCache {
    capacity: i64,
    cache: dictionary<u8[..16], Node?>&,
    head: Node?,
    tail: Node?,
    size: i64,
    free: Node?,
    nodes: Node[>..],
}

fn new_cache(capacity: i64, cache: dictionary<u8[..16], Node?>&) -> LruCache {
    cache.reserve(capacity);
    return LruCache { capacity: capacity, cache: cache, head: null, tail: null, size: 0, free: null, nodes: [] };
}

fn get(c: LruCache&, key: u8[..16]) -> u8[..32]? {
    let node = ::get(c.cache, key);
    guard node else { return null; }
    c.move_to_front(node);
    return node.value;
}

fn put(c: LruCache&, key: u8[..16], value: u8[:]) {
    let found = ::get(c.cache, key);
    if found {
        found.value = value;
        c.move_to_front(found);
        return;
    }

    if c.size >= c.capacity {
        c.remove_oldest();
    }

    let slot = c.free;
    let node: Node& = if slot {
        c.free .= slot.next;
        slot = new_node(key, value);
        slot
    } else {
        c.nodes.push(new_node(key, value))
    };

    c.cache.insert(key, node);
    c.add_to_front(node);
    c.size++;
}

fn len(c: LruCache&) -> i64 { c.size }

fn move_to_front(c: LruCache&, node: Node&) {
    if node .== c.head { return; }

    let prev = node.prev;
    let next = node.next;

    if prev { prev.next .= next; }
    if next { next.prev .= prev; }

    if node .== c.tail { c.tail .= prev; }

    node.prev .= null;
    node.next .= c.head;

    let head = c.head;
    if head { head.prev .= node; }

    c.head .= node;

    if c.tail == null { c.tail .= node; }
}

fn add_to_front(c: LruCache&, node: Node&) {
    node.next .= c.head;

    let head = c.head;
    if head { head.prev .= node; }

    c.head .= node;

    if c.tail == null { c.tail .= node; }
}

fn remove_oldest(c: LruCache&) {
    let tail_node = c.tail;
    if tail_node {
        c.cache.remove(tail_node.key);

        let prev = tail_node.prev;
        if prev { prev.next .= null; }

        c.tail .= prev;

        if tail_node .== c.head { c.head .= null; }

        tail_node.next .= c.free;
        c.free .= tail_node;
        c.size--;
    }
}

struct CacheSimulation {
    result_val: u32,
    values_size: i64,
    cache_size: i64,
    hits: u32,
    misses: u32,
    cache: LruCache,
}

fn new_cache_simulation(map: dictionary<u8[..16], Node?>&) -> CacheSimulation {
    let values_size = config_i64("Etc::CacheSimulation", "values");
    let cache_size = config_i64("Etc::CacheSimulation", "size");
    return CacheSimulation {
        result_val: 5432,
        values_size: values_size,
        cache_size: cache_size,
        hits: 0,
        misses: 0,
        cache: new_cache(cache_size, map),
    };
}

fn prepare(s: CacheSimulation&) {}

fn run(s: CacheSimulation&, iteration_id: i64) {
    for i in 1000 {
        let key: u8[..16] = str("item_", next_int(s.values_size));
        if s.cache.get(key) {
            s.hits++;
            s.cache.put(key, str("updated_", iteration_id));
        } else {
            s.misses++;
            s.cache.put(key, str("new_", iteration_id));
        }
    }
}

fn checksum(s: CacheSimulation&) -> u32 {
    var result = s.result_val;
    result = (result << 5) + s.hits;
    result = (result << 5) + s.misses;
    result = (result << 5) + s.cache.len() as! u32;
    return result;
}