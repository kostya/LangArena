namespace Benchmarks

open System

[<AbstractClass>]
type SortBenchmark() =
    inherit Benchmark()

    let mutable data = Array.empty<int>
    let mutable size = 0L
    let mutable result = 0u

    member _.Data with get() = data and set(v) = data <- v
    member _.Size with get() = size and set(v) = size <- v
    member _.Result with get() = result and set(v) = result <- v

    override this.Prepare() =
        size <- this.ConfigVal("size")
        data <- Array.init (int size) (fun _ -> Helper.NextInt(1000000))
        result <- 0u

    override this.Run(_: int64) =
        result <- result + uint32 data.[Helper.NextInt(int size)]
        let t = this.Test()
        result <- result + uint32 t.[Helper.NextInt(int size)]

    override this.Checksum = result

    abstract member Test: unit -> int[]

type SortMerge() =
    inherit SortBenchmark()

    let mergeSortInplace (arr: int[]) =
        let temp = Array.zeroCreate<int> arr.Length

        let rec mergeSortHelper left right =
            if left >= right then ()
            else
                let mid = (left + right) / 2
                mergeSortHelper left mid
                mergeSortHelper (mid + 1) right
                merge arr temp left mid right

        and merge (arr: int[]) (temp: int[]) left mid right =

            for i = left to right do
                temp.[i] <- arr.[i]

            let mutable iIdx = left
            let mutable jIdx = mid + 1
            let mutable k = left

            while iIdx <= mid && jIdx <= right do
                if temp.[iIdx] <= temp.[jIdx] then
                    arr.[k] <- temp.[iIdx]
                    iIdx <- iIdx + 1
                else
                    arr.[k] <- temp.[jIdx]
                    jIdx <- jIdx + 1
                k <- k + 1

            while iIdx <= mid do
                arr.[k] <- temp.[iIdx]
                iIdx <- iIdx + 1
                k <- k + 1

        mergeSortHelper 0 (arr.Length - 1)

    override this.Test() =
        let arr = Array.copy this.Data
        mergeSortInplace arr
        arr

type SortQuick() =
    inherit SortBenchmark()

    let quickSort (arr: int[]) =
        let rec sort low high =
            if low >= high then ()
            else
                let pivot = arr.[(low + high) / 2]
                let mutable i = low
                let mutable j = high

                while i <= j do
                    while arr.[i] < pivot do
                        i <- i + 1

                    while arr.[j] > pivot do
                        j <- j - 1

                    if i <= j then
                        let temp = arr.[i]
                        arr.[i] <- arr.[j]
                        arr.[j] <- temp
                        i <- i + 1
                        j <- j - 1

                sort low j
                sort i high

        sort 0 (arr.Length - 1)

    override this.Test() =
        let arr = Array.copy this.Data
        quickSort arr
        arr

type SortSelf() =
    inherit SortBenchmark()

    override this.Test() =
        let arr = Array.copy this.Data
        Array.Sort(arr)
        arr