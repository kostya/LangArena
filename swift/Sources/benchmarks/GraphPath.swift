import Foundation

class GraphPathBenchmark: BenchmarkProtocol {
  final class Graph {
    let vertices: Int
    let jumps: Int
    let jumpLen: Int
    var adj: [[Int]]

    init(vertices: Int, jumps: Int = 3, jumpLen: Int = 100) {
      self.vertices = vertices
      self.jumps = jumps
      self.jumpLen = jumpLen
      self.adj = Array(repeating: [Int](), count: vertices)
    }

    func addEdge(_ u: Int, _ v: Int) {
      adj[u].append(v)
      adj[v].append(u)
    }

    func generateRandom() {

      for i in 1..<vertices {
        addEdge(i, i - 1)
      }

      for v in 0..<vertices {
        let numJumps = Helper.nextInt(max: jumps)
        for _ in 0..<numJumps {
          let offset = Helper.nextInt(max: jumpLen) - jumpLen / 2
          let u = v + offset

          if u >= 0 && u < vertices && u != v {
            addEdge(v, u)
          }
        }
      }
    }
  }

  var graph: Graph!
  private var resultVal: UInt32 = 0

  init() {}

  func prepare() {
    let vertices = Int(configValue("vertices") ?? 0)
    let jumps = Int(configValue("jumps") ?? 0)
    let jumpLen = Int(configValue("jump_len") ?? 0)

    graph = Graph(vertices: vertices, jumps: jumps, jumpLen: jumpLen)
    graph.generateRandom()
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

  func name() -> String {
    return ""
  }
}

final class GraphPathBFS: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func bfsShortestPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    var visited = [Bool](repeating: false, count: graph.vertices)
    var queue: [(Int, Int)] = []
    queue.reserveCapacity(graph.vertices)
    visited[start] = true
    queue.append((start, 0))
    var front = 0

    while front < queue.count {
      let (v, dist) = queue[front]
      front += 1

      for neighbor in graph.adj[v] {
        if neighbor == target { return dist + 1 }
        if !visited[neighbor] {
          visited[neighbor] = true
          queue.append((neighbor, dist + 1))
        }
      }
    }
    return -1
  }

  override func test() -> Int64 {
    return Int64(bfsShortestPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::BFS"
  }
}

final class GraphPathDFS: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func dfsFindPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    var visited = [Bool](repeating: false, count: graph.vertices)
    var stack: [(Int, Int)] = [(start, 0)]
    var bestPath = Int.max

    while !stack.isEmpty {
      let (v, dist) = stack.removeLast()

      if visited[v] || dist >= bestPath {
        continue
      }

      visited[v] = true

      for neighbor in graph.adj[v] {
        if neighbor == target {
          if dist + 1 < bestPath {
            bestPath = dist + 1
          }
        } else if !visited[neighbor] {
          stack.append((neighbor, dist + 1))
        }
      }
    }

    return bestPath == Int.max ? -1 : bestPath
  }

  override func test() -> Int64 {
    return Int64(dfsFindPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::DFS"
  }
}

final class GraphPathAStar: GraphPathBenchmark {
  override init() {
    super.init()
  }

  private func heuristic(_ v: Int, _ target: Int) -> Int {
    return target - v
  }

  private struct PriorityQueue {
    private var vertices: [Int]
    private var priorities: [Int]
    private var size: Int

    init(capacity: Int) {
      vertices = [Int](repeating: 0, count: capacity)
      priorities = [Int](repeating: 0, count: capacity)
      size = 0
    }

    mutating func push(vertex: Int, priority: Int) {
      if size >= vertices.count {
        vertices.append(0)
        priorities.append(0)
      }

      var i = size
      size += 1
      vertices[i] = vertex
      priorities[i] = priority

      while i > 0 {
        let parent = (i - 1) / 2
        if priorities[parent] <= priorities[i] {
          break
        }
        vertices.swapAt(i, parent)
        priorities.swapAt(i, parent)
        i = parent
      }
    }

    mutating func pop() -> Int? {
      if size == 0 { return nil }

      let result = vertices[0]
      size -= 1

      if size > 0 {
        vertices[0] = vertices[size]
        priorities[0] = priorities[size]

        var i = 0
        while true {
          let left = 2 * i + 1
          let right = 2 * i + 2
          var smallest = i

          if left < size && priorities[left] < priorities[smallest] {
            smallest = left
          }
          if right < size && priorities[right] < priorities[smallest] {
            smallest = right
          }
          if smallest == i {
            break
          }
          vertices.swapAt(i, smallest)
          priorities.swapAt(i, smallest)
          i = smallest
        }
      }

      return result
    }

    var isEmpty: Bool { return size == 0 }
  }

  private func aStarShortestPath(_ start: Int, _ target: Int) -> Int {
    if start == target { return 0 }

    let vertices = graph.vertices
    var gScore = [Int](repeating: Int.max, count: vertices)
    var closed = [Bool](repeating: false, count: vertices)

    gScore[start] = 0

    var openSet = PriorityQueue(capacity: vertices)
    var inOpenSet = [Bool](repeating: false, count: vertices)

    openSet.push(vertex: start, priority: heuristic(start, target))
    inOpenSet[start] = true

    while let current = openSet.pop() {
      inOpenSet[current] = false

      if current == target {
        return gScore[current]
      }

      closed[current] = true

      for neighbor in graph.adj[current] {
        if closed[neighbor] { continue }

        let tentativeG = gScore[current] + 1

        if tentativeG < gScore[neighbor] {
          gScore[neighbor] = tentativeG
          let f = tentativeG + heuristic(neighbor, target)

          if !inOpenSet[neighbor] {
            openSet.push(vertex: neighbor, priority: f)
            inOpenSet[neighbor] = true
          }
        }
      }
    }

    return -1
  }

  override func test() -> Int64 {
    return Int64(aStarShortestPath(0, graph.vertices - 1))
  }

  override func name() -> String {
    return "Graph::AStar"
  }
}
