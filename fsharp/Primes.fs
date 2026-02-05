namespace Benchmarks

open System
open System.Collections.Generic

module PrimeHelpers =
    [<AllowNullLiteral>]
    type Node() =
        let children = Array.zeroCreate<Node> 10
        let mutable terminal = false

        member _.Terminal 
            with get() = terminal 
            and set(v) = terminal <- v

        member this.GetOrCreateChild(digit: int) =
            match children.[digit] with
            | null ->
                let child = Node()
                children.[digit] <- child
                child
            | child -> child

        member _.GetChild(digit: int) = children.[digit]

    type Sieve = private { Limit: int; IsPrime: bool[] }

    module Sieve =
        let create limit =
            let isPrime = Array.create (limit + 1) true
            if limit >= 2 then
                Array.fill isPrime 2 (isPrime.Length - 2) true
            { Limit = limit; IsPrime = isPrime }

        let calculatePrimes sieve =
            if sieve.Limit < 2 then [] else

            let sqrtLimit = int (sqrt (float sieve.Limit))
            let isPrime = sieve.IsPrime

            seq { 2 .. sqrtLimit }
            |> Seq.filter (fun p -> isPrime.[p])
            |> Seq.iter (fun p ->
                seq { p * p .. p .. sieve.Limit }
                |> Seq.iter (fun multiple -> isPrime.[multiple] <- false))

            let primeCount = 
                if sieve.Limit > 1000 then 
                    int (float sieve.Limit / log (float sieve.Limit))
                else 
                    sieve.Limit / 2

            seq {
                yield 2
                for p in 3 .. 2 .. sieve.Limit do
                    if isPrime.[p] then yield p
            }
            |> Seq.toList

        let primes limit = 
            limit |> create |> calculatePrimes

    module Trie =
        let private getDigits num =
            let rec loop n acc =
                if n = 0 then acc
                else loop (n / 10) ((n % 10) :: acc)
            loop num []

        let build primes =
            let root = Node()

            let addPrime prime =
                let digits = getDigits prime
                digits
                |> List.fold (fun (node: Node) digit -> 
                    node.GetOrCreateChild(digit)) root
                |> fun node -> node.Terminal <- true

            primes |> List.iter addPrime
            root

        let findWithPrefix (root: Node) prefixValue =
            let getPrefixDigits prefix =
                let rec loop n acc =
                    if n = 0 then acc
                    else loop (n / 10) ((n % 10) :: acc)
                loop prefix []

            let prefixDigits = getPrefixDigits prefixValue

            let startNode = 
                prefixDigits
                |> List.fold (fun (node: Node) digit -> 
                    match node with
                    | null -> null
                    | n -> n.GetChild(digit)) root

            if isNull startNode then [] else

            let rec bfs (queue: Queue<Node * int>) (results: int list) =
                if queue.Count = 0 then results
                else
                    let (node, number) = queue.Dequeue()

                    let newResults = 
                        if node.Terminal then number :: results 
                        else results

                    let childrenResults =
                        [0..9]
                        |> List.fold (fun acc digit ->
                            let child = node.GetChild(digit)
                            if not (isNull child) then
                                queue.Enqueue(child, number * 10 + digit)
                            acc) newResults

                    bfs queue childrenResults

            let queue = Queue<Node * int>()
            queue.Enqueue(startNode, prefixValue)

            bfs queue []
            |> List.sort

type Primes() =
    inherit Benchmark()

    let mutable limit = 0L
    let mutable prefix = 0L
    let mutable checksum = 5432u

    let updateChecksum (results: int list) =
        checksum <- checksum + uint32 results.Length
        results 
        |> List.fold (fun sum prime -> sum + uint32 prime) checksum

    override this.Checksum = checksum

    override this.Prepare() =
        limit <- this.ConfigVal("limit")
        prefix <- this.ConfigVal("prefix")
        checksum <- 5432u

    override this.Run(_: int64) =
        let primes = PrimeHelpers.Sieve.primes (int limit)
        let trie = PrimeHelpers.Trie.build primes
        let results = PrimeHelpers.Trie.findWithPrefix trie (int prefix)
        checksum <- updateChecksum results