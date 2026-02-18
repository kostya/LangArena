package benchmark

import "core:math"
import "core:slice"  

Node :: struct {
    children: [10]^Node,
    is_terminal: bool,
}

generate_primes :: proc(limit: int) -> []int {
    if limit < 2 {
        return make([]int, 0)
    }

    is_prime := make([]bool, limit + 1)
    defer delete(is_prime)

    for i in 2..=limit {
        is_prime[i] = true
    }

    sqrt_limit := int(math.sqrt(f64(limit)))

    for p in 2..=sqrt_limit {
        if is_prime[p] {
            for multiple := p * p; multiple <= limit; multiple += p {
                is_prime[multiple] = false
            }
        }
    }

    count := 0
    for i in 2..=limit {
        if is_prime[i] {
            count += 1
        }
    }

    primes := make([]int, count)
    index := 0
    for i in 2..=limit {
        if is_prime[i] {
            primes[index] = i
            index += 1
        }
    }

    return primes
}

build_trie :: proc(primes: []int) -> ^Node {
    root := new(Node)

    for prime in primes {
        current := root

        temp := prime
        digits: [20]int  
        count := 0

        for temp > 0 {
            digits[count] = temp % 10
            temp /= 10
            count += 1
        }

        if count == 0 {  
            digits[0] = 0
            count = 1
        }

        for i := count - 1; i >= 0; i -= 1 {
            digit := digits[i]

            if current.children[digit] == nil {
                current.children[digit] = new(Node)
            }
            current = current.children[digit]
        }
        current.is_terminal = true
    }

    return root
}

destroy_trie :: proc(node: ^Node) {
    if node == nil {
        return
    }

    for child in node.children {
        destroy_trie(child)
    }
    free(node)
}

Queue_Item :: struct {
    node: ^Node,
    number: int,
}

pop_front :: proc(queue: ^[dynamic]Queue_Item) -> Queue_Item {
    item := queue[0]
    ordered_remove(queue, 0)
    return item
}

find_primes_with_prefix :: proc(root: ^Node, prefix: int) -> []int {
    if root == nil {
        return make([]int, 0)
    }

    temp := prefix
    prefix_digits: [20]int
    count := 0

    if prefix == 0 {
        prefix_digits[0] = 0
        count = 1
    } else {
        for temp > 0 {
            prefix_digits[count] = temp % 10
            temp /= 10
            count += 1
        }
    }

    current := root
    for i := count - 1; i >= 0; i -= 1 {
        digit := prefix_digits[i]

        if current.children[digit] == nil {
            return make([]int, 0)
        }
        current = current.children[digit]
    }

    queue := make([dynamic]Queue_Item)
    defer delete(queue)

    append(&queue, Queue_Item{current, prefix})

    results := make([dynamic]int)
    defer delete(results)

    for len(queue) > 0 {
        item := pop_front(&queue)

        if item.node.is_terminal {
            append(&results, item.number)
        }

        for digit in 0..<10 {
            if item.node.children[digit] != nil {
                new_number := item.number * 10 + digit
                append(&queue, Queue_Item{item.node.children[digit], new_number})
            }
        }
    }

    slice.sort(results[:])

    final_result := make([]int, len(results))
    copy(final_result, results[:])
    return final_result
}

Primes :: struct {
    using base: Benchmark,
    n: int,
    prefix: int,
    result_val: u32,
}

primes_prepare :: proc(bench: ^Benchmark) {
    p := cast(^Primes)bench
    p.n = int(config_i64("Primes", "limit"))
    p.prefix = int(config_i64("Primes", "prefix"))
    p.result_val = 5432
}

primes_run :: proc(bench: ^Benchmark, iteration_id: int) {
    p := cast(^Primes)bench

    primes := generate_primes(p.n)
    defer delete(primes)

    trie := build_trie(primes)
    defer destroy_trie(trie)

    results := find_primes_with_prefix(trie, p.prefix)
    defer delete(results)

    p.result_val += u32(len(results))
    for prime in results {
        p.result_val += u32(prime)
    }
}

primes_checksum :: proc(bench: ^Benchmark) -> u32 {
    p := cast(^Primes)bench
    return p.result_val
}

create_primes :: proc() -> ^Benchmark {
    p := new(Primes)
    p.name = "Primes"
    p.vtable = default_vtable()

    p.vtable.run = primes_run
    p.vtable.checksum = primes_checksum
    p.vtable.prepare = primes_prepare

    return cast(^Benchmark)p
}