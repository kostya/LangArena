import Foundation

class GraphPathBenchmark: BenchmarkProtocol {
    final class Graph {
        let vertices: Int
        let adj: [[Int]]
        private let componentsCount: Int
        
        init(vertices: Int, components: Int = 10) {
            self.vertices = vertices
            self.componentsCount = components
            
            var tempAdj = Array(repeating: [Int](), count: vertices)
            let componentSize = vertices / componentsCount
            
            for c in 0..<componentsCount {
                let startIdx = c * componentSize
                var endIdx = (c + 1) * componentSize
                if c == componentsCount - 1 {
                    endIdx = vertices
                }
                
                // Делаем компоненту связной (точно как в Crystal)
                for i in (startIdx + 1)..<endIdx {
                    let parent = startIdx + Helper.nextInt(max: i - startIdx)
                    tempAdj[i].append(parent)
                    tempAdj[parent].append(i)
                }
                
                // Добавляем случайные рёбра внутри компоненты (точно как в Crystal)
                for _ in 0..<(componentSize * 2) {
                    let u = startIdx + Helper.nextInt(max: endIdx - startIdx)
                    let v = startIdx + Helper.nextInt(max: endIdx - startIdx)
                    if u != v {
                        tempAdj[u].append(v)
                        tempAdj[v].append(u)
                    }
                }
            }
            
            // ИСПРАВЛЕНО: Убрана сортировка! Оставляем дубликаты как есть, как в Crystal
            self.adj = tempAdj
            
            // Crystal код НЕ делает ни сортировку, ни удаление дубликатов!
            // adj[v] << neighbor может добавлять дубликаты
        }
        
        func sameComponent(_ u: Int, _ v: Int) -> Bool {
            let componentSize = vertices / componentsCount
            return (u / componentSize) == (v / componentSize)
        }
    }
    
    var graph: Graph!
    var pairs: [(Int, Int)] = []
    private var _result: Int64 = 0
    private var nPairs: Int = 0
    
    init() {
        nPairs = iterations
    }
    
    func prepare() {
        let vertices = nPairs * 10
        graph = Graph(vertices: vertices, components: max(10, vertices / 10_000))
        pairs = generatePairs(n: nPairs)
    }
    
    private func generatePairs(n: Int) -> [(Int, Int)] {
        var pairs = [(Int, Int)]()
        pairs.reserveCapacity(n)
        let componentSize = graph.vertices / 10
        
        for _ in 0..<n {
            if Helper.nextInt(max: 100) < 70 {
                // В одной компоненте (70% случаев) - как в Crystal
                let component = Helper.nextInt(max: 10)
                let start = component * componentSize + Helper.nextInt(max: componentSize)
                var end: Int
                repeat {
                    end = component * componentSize + Helper.nextInt(max: componentSize)
                } while end == start
                pairs.append((start, end))
            } else {
                // В разных компонентах (30% случаев) - как в Crystal
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
        return 0 // Override in subclasses
    }
    
    func run() {
        _result = test()
    }
    
    var result: Int64 {
        return _result
    }
}

