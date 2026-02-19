mutable struct Primes <: AbstractBenchmark
    n::Int64
    prefix::Int64
    result::UInt32

    function Primes()
        n = Helper.config_i64("Primes", "limit")
        prefix = Helper.config_i64("Primes", "prefix")
        new(n, prefix, UInt32(5432))
    end
end

name(b::Primes)::String = "Primes"

mutable struct PrimesNode
    children::Vector{Union{PrimesNode,Nothing}}
    terminal::Bool

    function PrimesNode()
        children = Vector{Union{PrimesNode,Nothing}}(nothing, 10)
        new(children, false)
    end
end

function sieve(limit::Int32)::Vector{Int32}
    if limit < 2
        return Int32[]
    end

    is_prime = trues(limit + 1)
    is_prime[1] = false

    sqrt_limit = isqrt(limit)

    for p = 2:sqrt_limit
        if is_prime[p]
            start = p * p
            for multiple = start:p:limit
                is_prime[multiple] = false
            end
        end
    end

    capacity = limit ÷ max(Int(round(log(limit))), 10)
    primes = Vector{Int32}(undef, 0)
    sizehint!(primes, capacity)

    push!(primes, 2)
    for p = 3:2:limit
        if is_prime[p]
            push!(primes, p)
        end
    end

    return primes
end

function generate_trie(primes::Vector{Int32})::PrimesNode
    root = PrimesNode()

    for prime in primes
        node = root

        digits = Int[]
        temp = prime
        while temp > 0
            push!(digits, temp % 10)
            temp ÷= 10
        end
        reverse!(digits)

        for digit in digits
            if node.children[digit+1] === nothing
                node.children[digit+1] = PrimesNode()
            end
            node = node.children[digit+1]
        end

        node.terminal = true
    end

    return root
end

function find_primes_with_prefix(trie::PrimesNode, prefix::Int32)::Vector{Int32}

    node = trie
    current = 0

    prefix_digits = Int[]
    temp = prefix
    while temp > 0
        push!(prefix_digits, temp % 10)
        temp ÷= 10
    end
    reverse!(prefix_digits)

    for digit in prefix_digits
        current = current * 10 + digit
        child = node.children[digit+1]
        if child === nothing
            return Int32[]
        end
        node = child
    end

    results = Int32[]
    queue = Vector{Tuple{PrimesNode,Int32}}()
    push!(queue, (node, current))

    idx = 1
    while idx <= length(queue)
        current_node, current_num = queue[idx]
        idx += 1

        if current_node.terminal
            push!(results, current_num)
        end

        for digit = 0:9
            child = current_node.children[digit+1]
            if child !== nothing
                push!(queue, (child, current_num * 10 + digit))
            end
        end
    end

    sort!(results)
    return results
end

function run(b::Primes, iteration_id::Int64)

    primes_list = sieve(Int32(b.n))

    trie = generate_trie(primes_list)

    results = find_primes_with_prefix(trie, Int32(b.prefix))

    b.result += UInt32(length(results))
    for prime in results
        b.result += UInt32(prime)
    end

    b.result &= 0xffffffff
end

checksum(b::Primes)::UInt32 = b.result
