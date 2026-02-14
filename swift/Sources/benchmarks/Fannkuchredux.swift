import Foundation

final class Fannkuchredux: BenchmarkProtocol {
    private var n: Int64 = 0
    private var resultVal: UInt32 = 0

    init() {
        n = configValue("n") ?? 0
    }

    private struct Result {
        let checksum: Int
        let maxFlipsCount: Int
    }

    private func fannkuchredux(_ n: Int) -> Result {
        var perm1 = ContiguousArray(0..<n)
        var perm = ContiguousArray(repeating: 0, count: n)
        var count = ContiguousArray(repeating: 0, count: n)
        var maxFlipsCount = 0
        var permCount = 0
        var checksum = 0
        var r = n

        while true {
            while r > 1 {
                count[r - 1] = r
                r -= 1
            }

            perm = perm1
            var flipsCount = 0
            var k = perm[0]

            while k != 0 {

                var i = 0
                var j = k
                while i < j {
                    perm.swapAt(i, j)
                    i += 1
                    j -= 1
                }
                flipsCount += 1
                k = perm[0]
            }

            maxFlipsCount = max(maxFlipsCount, flipsCount)
            checksum += (permCount & 1) == 0 ? flipsCount : -flipsCount

            while true {
                if r == n {
                    return Result(checksum: checksum, maxFlipsCount: maxFlipsCount)
                }

                let perm0 = perm1[0]
                for i in 0..<r {
                    perm1[i] = perm1[i + 1]
                }
                perm1[r] = perm0

                count[r] -= 1
                if count[r] > 0 { break }
                r += 1
            }
            permCount += 1
        }
    }

    func run(iterationId: Int) {
        let result = fannkuchredux(Int(n))
        resultVal &+= UInt32(result.checksum) * 100 + UInt32(result.maxFlipsCount)
    }

    var checksum: UInt32 {
        return resultVal
    }

    func prepare() {}
}