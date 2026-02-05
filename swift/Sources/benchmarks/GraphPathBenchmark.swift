import Foundation

class GraphPathBenchmark: BenchmarkProtocol {
    final class Graph {
        let vertices: Int
        let adj: [[Int]]

        init(vertices: Int, components: Int = 10) {
            self.vertices = vertices

            var tempAdj = Array(repeating: [Int](), count: vertices)
            let componentSize = vertices / components

            for c in 0..<components {
                let startIdx = c * componentSize
                var endIdx = (c + 1) * componentSize
                if c == components - 1 {
                    endIdx = vertices
                }

                for i in (startIdx + 1)..<endIdx {
                    let parent = startIdx + Helper.nextInt(max: i - startIdx)
                    tempAdj[i].append(parent)
                    tempAdj[parent].append(i)
                }

                for _ in 0..<(componentSize * 2) {
                    let u = startIdx + Helper.nextInt(max: endIdx - startIdx)
                    let v = startIdx + Helper.nextInt(max: endIdx - startIdx)
                    if u != v {
                        tempAdj[u].append(v)
                        tempAdj[v].append(u)
                    }
                }
            }

            self.adj = tempAdj
        }

        func generateRandom() {

        }
    }

    var graph: Graph!
    var pairs: [(Int, Int)] = []
    private var nPairs: Int64 = 0
    private var resultVal: UInt32 = 0

    init() {

    }

    func prepare() {
        if nPairs == 0 {
            nPairs = configValue("pairs") ?? 0
            let vertices = Int(configValue("vertices") ?? 0)
            let comps = max(10, vertices / 10_000)
            graph = Graph(vertices: vertices, components: comps)
            pairs = generatePairs(n: Int(nPairs))
        }
    }

    private func generatePairs(n: Int) -> [(Int, Int)] {
        var pairs = [(Int, Int)]()
        pairs.reserveCapacity(n)
        let componentSize = graph.vertices / 10

        for _ in 0..<n {
            if Helper.nextInt(max: 100) < 70 {
                let component = Helper.nextInt(max: 10)
                let start = component * componentSize + Helper.nextInt(max: componentSize)
                var end: Int
                repeat {
                    end = component * componentSize + Helper.nextInt(max: componentSize)
                } while end == start
                pairs.append((start, end))
            } else {
                let c1 = Helper.nextInt(max: 10)
                var c2 = Helper.nextInt(max: 10)
                while c2 == c1 {
                    c2 = Helper.nextInt(max: 10)
                }
                let start = c1 * componentSize + Helper.nextInt(max: componentSize)
                let end = c2 * componentSize + Helper.nextInt(max: componentSize)
                pairs.append((start, end))
            }
        }
        return pairs
    }

    func test() -> Int64 {
        return 0
    }

    func run(iterationId: Int) {
        resultVal &+= UInt32(test())
    }

    var checksum: UInt32 {
        return resultVal
    }

    var name: String { return "GraphPathBenchmark" }
}