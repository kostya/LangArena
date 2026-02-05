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
        var perm1 = Array(0..<32)
        var perm = Array(0..<32)
        var count = Array(0..<32)
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
                let k2 = (k + 1) / 2
                for i in 0..<k2 {
                    let j = k - i
                    perm.swapAt(i, j)
                }
                flipsCount += 1
                k = perm[0]
            }

            if flipsCount > maxFlipsCount {
                maxFlipsCount = flipsCount
            }

            if permCount % 2 == 0 {
                checksum += flipsCount
            } else {
                checksum -= flipsCount
            }

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
                let cntr = count[r]
                if cntr > 0 { break }
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