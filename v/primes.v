module primes

import benchmark
import helper
import math

pub struct Primes {
	benchmark.BaseBenchmark
	n      i64
	prefix i64
mut:
	result_val u32
}

pub fn new_primes() &benchmark.IBenchmark {
	mut bench := &Primes{
		BaseBenchmark: benchmark.new_base_benchmark('Primes')
		n:             helper.config_i64('Primes', 'limit')
		prefix:        helper.config_i64('Primes', 'prefix')
		result_val:    5432
	}
	return bench
}

pub fn (b Primes) name() string {
	return 'Primes'
}

@[heap]
struct TrieNode {
mut:
	children    [10]&TrieNode
	is_terminal bool
}

fn new_trie_node() &TrieNode {
	mut node := &TrieNode{}
	node.is_terminal = false
	for i in 0 .. 10 {
		node.children[i] = unsafe { nil }
	}
	return node
}

struct BfsItem {
	node   &TrieNode
	number int
}

fn generate_primes(limit int) []int {
	if limit < 2 {
		return []int{}
	}

	mut is_prime := []bool{len: limit + 1, init: true}
	is_prime[0] = false
	is_prime[1] = false

	sqrt_limit := int(math.sqrt(f64(limit)))

	for p in 2 .. sqrt_limit + 1 {
		if is_prime[p] {
			mut multiple := p * p
			for multiple <= limit {
				is_prime[multiple] = false
				multiple += p
			}
		}
	}

	mut primes_list := []int{}
	for i in 2 .. limit + 1 {
		if is_prime[i] {
			primes_list << i
		}
	}

	return primes_list
}

fn build_trie(primes_list []int) &TrieNode {
	mut root := new_trie_node()

	for prime in primes_list {
		mut current := root
		digits := prime.str()

		for digit_char in digits {
			digit := int(digit_char - `0`)

			if unsafe { current.children[digit] == nil } {
				current.children[digit] = new_trie_node()
			}
			current = current.children[digit]
		}
		current.is_terminal = true
	}

	return root
}

fn find_primes_with_prefix(trie_root &TrieNode, prefix int) []int {
	prefix_str := prefix.str()

	mut node := unsafe { &TrieNode(trie_root) }
	for digit_char in prefix_str {
		digit := int(digit_char - `0`)

		if unsafe { node.children[digit] == nil } {
			return []int{}
		}
		node = node.children[digit]
	}

	mut results := []int{}
	mut bfs_queue := []BfsItem{}
	bfs_queue << BfsItem{node, prefix}

	for bfs_queue.len > 0 {
		item := bfs_queue[0]
		bfs_queue.delete(0)

		if item.node.is_terminal {
			results << item.number
		}

		for digit in 0 .. 10 {
			if unsafe { item.node.children[digit] != nil } {
				new_number := item.number * 10 + digit
				bfs_queue << BfsItem{item.node.children[digit], new_number}
			}
		}
	}

	results.sort()
	return results
}

pub fn (mut p Primes) run(iteration_id int) {
	primes_list := generate_primes(int(p.n))

	trie_root := build_trie(primes_list)

	results := find_primes_with_prefix(trie_root, int(p.prefix))

	p.result_val += u32(results.len)
	for prime in results {
		p.result_val += u32(prime)
	}
}

pub fn (p Primes) checksum() u32 {
	return p.result_val
}

pub fn (mut p Primes) prepare() {
	p.result_val = 5432
}
