using ..BenchmarkFramework

mutable struct CSNode{K,V}
    key::K
    value::V
    prev::Union{CSNode{K,V},Nothing}
    next::Union{CSNode{K,V},Nothing}

    function CSNode{K,V}(key::K, value::V) where {K,V}
        new{K,V}(key, value, nothing, nothing)
    end
end

mutable struct LRUCache{K,V}
    capacity::Int32
    cache::Dict{K,CSNode{K,V}}
    head::Union{CSNode{K,V},Nothing}
    tail::Union{CSNode{K,V},Nothing}
    size::Int32

    function LRUCache{K,V}(capacity::Int32) where {K,V}
        new{K,V}(capacity, Dict{K,CSNode{K,V}}(), nothing, nothing, 0)
    end
end

function cache_get(cache::LRUCache{K,V}, key::K)::Union{V,Nothing} where {K,V}

    if haskey(cache.cache, key)
        node = cache.cache[key]

        move_to_front!(cache, node)
        return node.value
    end
    return nothing
end

function cache_put!(cache::LRUCache{K,V}, key::K, value::V) where {K,V}
    if haskey(cache.cache, key)

        node = cache.cache[key]
        node.value = value
        move_to_front!(cache, node)
        return
    end

    if cache.size >= cache.capacity
        remove_oldest!(cache)
    end

    node = CSNode{K,V}(key, value)

    cache.cache[key] = node

    add_to_front!(cache, node)

    cache.size += 1
end

function cache_size(cache::LRUCache)::Int32
    return cache.size
end

function move_to_front!(cache::LRUCache{K,V}, node::CSNode{K,V}) where {K,V}

    if node === cache.head
        return
    end

    if node.prev !== nothing
        node.prev.next = node.next
    end
    if node.next !== nothing
        node.next.prev = node.prev
    end

    if node === cache.tail
        cache.tail = node.prev
    end

    node.prev = nothing
    node.next = cache.head
    if cache.head !== nothing
        cache.head.prev = node
    end
    cache.head = node

    if cache.tail === nothing
        cache.tail = node
    end
end

function add_to_front!(cache::LRUCache{K,V}, node::CSNode{K,V}) where {K,V}
    node.next = cache.head
    if cache.head !== nothing
        cache.head.prev = node
    end
    cache.head = node

    if cache.tail === nothing
        cache.tail = node
    end
end

function remove_oldest!(cache::LRUCache{K,V}) where {K,V}
    if cache.tail === nothing
        return
    end

    oldest = cache.tail

    delete!(cache.cache, oldest.key)

    if oldest.prev !== nothing
        oldest.prev.next = nothing
    end
    cache.tail = oldest.prev

    if cache.head === oldest
        cache.head = nothing
    end

    cache.size -= 1
end

mutable struct CacheSimulation <: AbstractBenchmark
    values_size::Int32
    cache::LRUCache{String,String}
    result::UInt32
    hits::Int32
    misses::Int32

    function CacheSimulation()
        values_val = Helper.config_i64("Etc::CacheSimulation", "values")
        cache_size_val = Helper.config_i64("Etc::CacheSimulation", "size")

        cache = LRUCache{String,String}(Int32(cache_size_val))
        new(Int32(values_val), cache, UInt32(5432), Int32(0), Int32(0))
    end
end

name(b::CacheSimulation)::String = "Etc::CacheSimulation"

function prepare(b::CacheSimulation)

    b.hits = 0
    b.misses = 0
end

function run(b::CacheSimulation, iteration_id::Int64)
    key = "item_$(Helper.next_int(b.values_size))"

    value = cache_get(b.cache, key)
    if value !== nothing
        b.hits += 1
        cache_put!(b.cache, key, "updated_$iteration_id")
    else
        b.misses += 1
        cache_put!(b.cache, key, "new_$iteration_id")
    end
end

function checksum(b::CacheSimulation)::UInt32

    b.result = ((b.result << 5) + b.hits) & 0xffffffff
    b.result = ((b.result << 5) + b.misses) & 0xffffffff
    b.result = ((b.result << 5) + cache_size(b.cache)) & 0xffffffff
    return b.result
end
