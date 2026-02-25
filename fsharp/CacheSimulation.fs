namespace Benchmarks

open System.Collections.Generic

[<AllowNullLiteral>]
type private Node<'K, 'V>() =
    let mutable key = Unchecked.defaultof<'K>
    let mutable value = Unchecked.defaultof<'V>
    let mutable prev: Node<'K, 'V> = null
    let mutable next: Node<'K, 'V> = null

    member _.Key = key
    member _.Value = value
    member _.Prev = prev
    member _.Next = next

    member _.SetKey(v) = key <- v
    member _.SetValue(v) = value <- v
    member _.SetPrev(v) = prev <- v
    member _.SetNext(v) = next <- v

[<AllowNullLiteral>]
type private LRUCache<'K, 'V when 'K : equality>(capacity: int) =
    let cache = Dictionary<'K, Node<'K, 'V>>()
    let mutable head: Node<'K, 'V> = null
    let mutable tail: Node<'K, 'V> = null
    let mutable size = 0

    let moveToFront (node: Node<'K, 'V>) =
        if obj.ReferenceEquals(node, head) then ()  
        else

            let prevNode = node.Prev
            let nextNode = node.Next

            if not (isNull prevNode) then
                prevNode.SetNext(nextNode)

            if not (isNull nextNode) then
                nextNode.SetPrev(prevNode)

            if obj.ReferenceEquals(node, tail) then
                tail <- prevNode

            node.SetPrev(null)
            node.SetNext(head)

            if not (isNull head) then
                head.SetPrev(node)

            head <- node

            if isNull tail then
                tail <- node

    let addToFront (node: Node<'K, 'V>) =
        node.SetPrev(null)
        node.SetNext(head)

        if not (isNull head) then
            head.SetPrev(node)
        else

            tail <- node

        head <- node

    let removeOldest () =
        if not (isNull tail) then
            let oldest = tail
            cache.Remove(oldest.Key) |> ignore

            let oldestPrev = oldest.Prev
            if not (isNull oldestPrev) then
                oldestPrev.SetNext(null)
                tail <- oldestPrev
            else

                head <- null
                tail <- null

            size <- size - 1

    member _.Size = size

    member this.Get(key: 'K) =
        match cache.TryGetValue(key) with
        | true, node ->
            moveToFront node
            Some node.Value
        | false, _ -> None

    member this.Put(key: 'K, value: 'V) =
        match cache.TryGetValue(key) with
        | true, node ->
            node.SetValue(value)
            moveToFront node
        | false, _ ->
            if size >= capacity && capacity > 0 then
                removeOldest ()

            let node = Node<'K, 'V>()
            node.SetKey(key)
            node.SetValue(value)
            cache.[key] <- node
            addToFront node
            size <- size + 1

type CacheSimulation() =
    inherit Benchmark()

    let mutable result = 5432u
    let mutable valuesSize = 0
    let mutable cacheSize = 0
    let mutable cache: LRUCache<string, string> = null
    let mutable hits = 0
    let mutable misses = 0

    let sb = System.Text.StringBuilder(32)

    let buildKey (index: int) =
        sb.Clear()
        sb.Append("item_")
        sb.Append(index)
        sb.ToString()

    let buildUpdatedValue (iterations: int64) =
        sb.Clear()
        sb.Append("updated_")
        sb.Append(iterations)
        sb.ToString()

    let buildNewValue (iterations: int64) =
        sb.Clear()
        sb.Append("new_")
        sb.Append(iterations)
        sb.ToString()

    override this.Checksum =
        let mutable finalResult = result
        finalResult <- (finalResult <<< 5) + uint32 hits
        finalResult <- (finalResult <<< 5) + uint32 misses
        if not (isNull cache) then 
            finalResult <- (finalResult <<< 5) + uint32 cache.Size
        else 
            finalResult <- finalResult <<< 5
        finalResult
    override this.Name = "Etc::CacheSimulation"

    override this.Prepare() =
        valuesSize <- int (this.ConfigVal("values"))
        cacheSize <- int (this.ConfigVal("size"))
        cache <- LRUCache<string, string>(cacheSize)
        hits <- 0
        misses <- 0
        result <- 5432u

    override this.Run(_: int64) =
        if not (isNull cache) then
            for т in 1 .. 1000 do
                let key = buildKey (Helper.NextInt(valuesSize))

                match cache.Get(key) with
                | Some _ ->
                    hits <- hits + 1
                    cache.Put(key, buildUpdatedValue this.Iterations)
                | None ->
                    misses <- misses + 1
                    cache.Put(key, buildNewValue this.Iterations)