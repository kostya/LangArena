import Foundation
import BigInt

final class Pidigits: BenchmarkProtocol {
    private var output = ""
    private var nn: Int32 = 0

    init() {
        nn = Int32(configValue("amount") ?? 0)
    }

    func prepare() {
        output = ""
    }

    func run(iterationId: Int) {
        var i = 0
        var k = 0
        var ns = BigInt(0)
        var a = BigInt(0)
        var t: BigInt
        var u: BigInt
        var k1 = BigInt(1)
        var n = BigInt(1)
        var d = BigInt(1)

        while true {
            k += 1
            t = n << 1
            n *= BigInt(k)
            k1 += 2
            a = (a + t) * k1
            d *= k1

            if a >= n {
                let temp = n * 3 + a
                let (q, r) = temp.quotientAndRemainder(dividingBy: d)
                t = q
                u = r + n

                if d > u {
                    ns = ns * 10 + t
                    i += 1
                    if i % 10 == 0 {
                        let formatted = String(format: "%010lld\t:%d\n", ns.int64 ?? 0, i)
                        output.append(formatted)
                        ns = 0
                    }
                    if i >= nn { break }
                    a = (a - (d * t)) * 10
                    n *= 10
                }
            }
        }

        if ns != 0 {
            let formatted = String(format: "%010lld\t:%d\n", ns.int64 ?? 0, i)
            output.append(formatted)
        }
    }

    var checksum: UInt32 {
        return Helper.checksum(output)
    }
}

extension BigInt {
    var int64: Int64? {
        guard bitWidth <= 64 else { return nil }
        return Int64(self)
    }
}