namespace Benchmarks

open System

type Fannkuchredux() =
    inherit Benchmark()

    let mutable n = 0L
    let mutable result = 0u

    let fannkuchreduxAlgo (n: int) =
        let perm1 = Array.zeroCreate<int> 32
        let perm = Array.zeroCreate<int> 32
        let count = Array.zeroCreate<int> 32

        for i = 0 to n - 1 do
            perm1.[i] <- i

        let mutable maxFlipsCount = 0
        let mutable permCount = 0
        let mutable checksum = 0
        let mutable r = n
        let mutable doneFlag = false
        let mutable finalResult = (0, 0)

        while not doneFlag do
            while r > 1 do
                count.[r - 1] <- r
                r <- r - 1

            Array.Copy(perm1, perm, n)

            let mutable flipsCount = 0
            let mutable k = perm.[0]

            while k <> 0 do
                let mutable i = 0
                let mutable j = k

                while i < j do
                    let temp = perm.[i]
                    perm.[i] <- perm.[j]
                    perm.[j] <- temp
                    i <- i + 1
                    j <- j - 1

                flipsCount <- flipsCount + 1
                k <- perm.[0]

            if flipsCount > maxFlipsCount then
                maxFlipsCount <- flipsCount

            if permCount % 2 = 0 then
                checksum <- checksum + flipsCount
            else
                checksum <- checksum - flipsCount

            let mutable innerDone = false

            while not innerDone do
                if r = n then
                    doneFlag <- true
                    finalResult <- (checksum, maxFlipsCount)
                    innerDone <- true
                else
                    let perm0 = perm1.[0]
                    for i = 0 to r - 1 do
                        perm1.[i] <- perm1.[i + 1]
                    perm1.[r] <- perm0

                    count.[r] <- count.[r] - 1
                    let cntr = count.[r]

                    if cntr > 0 then
                        innerDone <- true
                    else
                        r <- r + 1

            if not doneFlag then
                permCount <- permCount + 1

        finalResult

    override this.Checksum = result
    override this.Name = "CLBG::Fannkuchredux"

    override this.Prepare() =
        n <- this.ConfigVal("n")
        result <- 0u

    override this.Run(_: int64) =
        let (checksum, maxFlipsCount) = fannkuchreduxAlgo (int n)
        result <- result + uint32 (checksum * 100 + maxFlipsCount)