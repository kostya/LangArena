import Foundation

enum CellKind: Int {
  case wall = 0
  case space = 1
  case start = 2
  case finish = 3
  case border = 4
  case path = 5

  var isWalkable: Bool {
    return self == .space || self == .start || self == .finish
  }
}

final class Cell {
  var kind: CellKind = .wall
  var neighbors: [Cell] = []
  let x: Int
  let y: Int

  init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  func reset() {
    if kind == .space {
      kind = .wall
    }
  }
}

final class Maze {
  let width: Int
  let height: Int
  let cells: [[Cell]]
  let start: Cell
  let finish: Cell

  init(width: Int, height: Int) {
    let w = max(width, 5)
    let h = max(height, 5)

    self.width = w
    self.height = h

    var tempCells: [[Cell]] = []
    for y in 0..<h {
      var row: [Cell] = []
      for x in 0..<w {
        row.append(Cell(x: x, y: y))
      }
      tempCells.append(row)
    }
    self.cells = tempCells

    self.start = cells[1][1]
    self.finish = cells[h - 2][w - 2]
    start.kind = .start
    finish.kind = .finish

    updateNeighbors()
  }

  func updateNeighbors() {
    for y in 0..<height {
      for x in 0..<width {
        let cell = cells[y][x]
        cell.neighbors.removeAll()

        if x > 0 && y > 0 && x < width - 1 && y < height - 1 {
          cell.neighbors.append(cells[y - 1][x])
          cell.neighbors.append(cells[y + 1][x])
          cell.neighbors.append(cells[y][x + 1])
          cell.neighbors.append(cells[y][x - 1])

          for _ in 0..<4 {
            let i = Helper.nextInt(max: 4)
            let j = Helper.nextInt(max: 4)
            if i != j {
              cell.neighbors.swapAt(i, j)
            }
          }
        } else {
          cell.kind = .border
        }
      }
    }
  }

  func reset() {
    for row in cells {
      for cell in row {
        cell.reset()
      }
    }
    start.kind = .start
    finish.kind = .finish
  }

  func dig(startCell: Cell) {
    var stack: [Cell] = []
    stack.reserveCapacity(width * height)
    stack.append(startCell)

    while let cell = stack.popLast() {

      var walkable = 0
      for n in cell.neighbors {
        if n.kind.isWalkable {
          walkable += 1
        }
      }

      if walkable == 1 {
        cell.kind = .space
        for n in cell.neighbors {
          if n.kind == .wall {
            stack.append(n)
          }
        }
      }
    }
  }

  func ensureOpenFinish(startCell: Cell) {
    var stack: [Cell] = []
    stack.reserveCapacity(width * height)
    stack.append(startCell)

    while let cell = stack.popLast() {
      cell.kind = .space

      var walkable = 0
      for n in cell.neighbors {
        if n.kind.isWalkable {
          walkable += 1
        }
      }

      if walkable > 1 {
        continue
      }

      for n in cell.neighbors {
        if n.kind == .wall {
          stack.append(n)
        }
      }
    }
  }

  func generate() {
    for n in start.neighbors where n.kind == .wall {
      dig(startCell: n)
    }

    for n in finish.neighbors where n.kind == .wall {
      ensureOpenFinish(startCell: n)
    }
  }

  func middleCell() -> Cell {
    return cells[height / 2][width / 2]
  }

  func checksum() -> UInt32 {
    var hasher: UInt32 = 2_166_136_261
    let prime: UInt32 = 16_777_619

    for y in 0..<height {
      for x in 0..<width {
        if cells[y][x].kind == .space {
          let val = UInt32(x * y)
          hasher = (hasher ^ val) &* prime
        }
      }
    }
    return hasher
  }

  func printToConsole() {
    for y in 0..<height {
      for x in 0..<width {
        switch cells[y][x].kind {
        case .space: print(" ", terminator: "")
        case .wall: print("\u{001B}[34m#\u{001B}[0m", terminator: "")
        case .border: print("\u{001B}[31mO\u{001B}[0m", terminator: "")
        case .start: print("\u{001B}[32m>\u{001B}[0m", terminator: "")
        case .finish: print("\u{001B}[32m<\u{001B}[0m", terminator: "")
        case .path: print("\u{001B}[33m.\u{001B}[0m", terminator: "")
        }
      }
      print()
    }
    print()
  }
}

final class MazeGenerator: BenchmarkProtocol {
  private var resultVal: UInt32 = 0
  private var width: Int = 0
  private var height: Int = 0
  private var maze: Maze?

  init() {
    width = Int(configValue("w") ?? 50)
    height = Int(configValue("h") ?? 50)
  }

  func prepare() {
    maze = Maze(width: width, height: height)
    resultVal = 0
  }

  func run(iterationId: Int) {
    guard let maze = maze else { return }
    maze.reset()
    maze.generate()
    resultVal = resultVal &+ UInt32(maze.middleCell().kind.rawValue)
  }

  var checksum: UInt32 {
    guard let maze = maze else { return 0 }
    return resultVal &+ maze.checksum()
  }

  func name() -> String {
    return "Maze::Generator"
  }
}

final class MazeBFS: BenchmarkProtocol {
  private var resultVal: UInt32 = 0
  private var width: Int = 0
  private var height: Int = 0
  private var maze: Maze?
  private var path: [Cell] = []

  struct PathNode {
    let cell: Cell
    let parent: Int
  }

  init() {
    width = Int(configValue("w") ?? 50)
    height = Int(configValue("h") ?? 50)
  }

  func prepare() {
    maze = Maze(width: width, height: height)
    maze?.generate()
    resultVal = 0
    path = []
  }

  func bfs(start: Cell, target: Cell) -> [Cell] {
    if start === target {
      return [start]
    }

    var queue: [Int] = []
    var visited: [[Bool]] = Array(
      repeating: Array(repeating: false, count: width),
      count: height
    )
    var pathNodes: [PathNode] = []

    visited[start.y][start.x] = true
    pathNodes.append(PathNode(cell: start, parent: -1))
    queue.append(0)

    while !queue.isEmpty {
      let pathId = queue.removeFirst()
      let node = pathNodes[pathId]

      for neighbor in node.cell.neighbors {
        if neighbor === target {
          var result: [Cell] = [target]
          var cur = pathId
          while cur >= 0 {
            result.append(pathNodes[cur].cell)
            cur = pathNodes[cur].parent
          }
          return result.reversed()
        }

        if neighbor.kind.isWalkable && !visited[neighbor.y][neighbor.x] {
          visited[neighbor.y][neighbor.x] = true
          pathNodes.append(PathNode(cell: neighbor, parent: pathId))
          queue.append(pathNodes.count - 1)
        }
      }
    }

    return []
  }

  func midCellChecksum(path: [Cell]) -> UInt32 {
    if path.isEmpty { return 0 }
    let cell = path[path.count / 2]
    return UInt32(cell.x * cell.y)
  }

  func run(iterationId: Int) {
    guard let maze = maze else { return }
    path = bfs(start: maze.start, target: maze.finish)
    resultVal = resultVal &+ UInt32(path.count)
  }

  var checksum: UInt32 {
    return resultVal &+ midCellChecksum(path: path)
  }

  func name() -> String {
    return "Maze::BFS"
  }
}

final class MazeAStar: BenchmarkProtocol {
  private var resultVal: UInt32 = 0
  private var width: Int = 0
  private var height: Int = 0
  private var maze: Maze?
  private var path: [Cell] = []

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

  init() {
    width = Int(configValue("w") ?? 50)
    height = Int(configValue("h") ?? 50)
  }

  func prepare() {
    maze = Maze(width: width, height: height)
    maze?.generate()
    resultVal = 0
    path = []
  }

  private func heuristic(a: Cell, b: Cell) -> Int {
    return abs(a.x - b.x) + abs(a.y - b.y)
  }

  private func idx(y: Int, x: Int) -> Int {
    return y * width + x
  }

  private func astar(start: Cell, target: Cell) -> [Cell] {
    if start === target {
      return [start]
    }

    let size = width * height
    var cameFrom = [Int](repeating: -1, count: size)
    var gScore = [Int](repeating: Int.max, count: size)
    var bestF = [Int](repeating: Int.max, count: size)

    let startIdx = idx(y: start.y, x: start.x)
    let targetIdx = idx(y: target.y, x: target.x)

    var openSet = PriorityQueue(capacity: size)
    var inOpen = [Bool](repeating: false, count: size)

    gScore[startIdx] = 0
    let fStart = heuristic(a: start, b: target)
    openSet.push(vertex: startIdx, priority: fStart)
    bestF[startIdx] = fStart
    inOpen[startIdx] = true

    while !openSet.isEmpty {
      guard let currentIdx = openSet.pop() else { break }
      inOpen[currentIdx] = false

      if currentIdx == targetIdx {
        var result: [Cell] = []
        var cur = currentIdx
        while cur != -1 {
          let y = cur / width
          let x = cur % width
          if let maze = maze {
            result.append(maze.cells[y][x])
          }
          cur = cameFrom[cur]
        }
        return result.reversed()
      }

      let currentY = currentIdx / width
      let currentX = currentIdx % width
      guard let currentCell = maze?.cells[currentY][currentX] else { continue }
      let currentG = gScore[currentIdx]

      for neighbor in currentCell.neighbors {
        guard neighbor.kind.isWalkable else { continue }

        let neighborIdx = idx(y: neighbor.y, x: neighbor.x)
        let tentativeG = currentG + 1

        if tentativeG < gScore[neighborIdx] {
          cameFrom[neighborIdx] = currentIdx
          gScore[neighborIdx] = tentativeG
          let fNew = tentativeG + heuristic(a: neighbor, b: target)

          if fNew < bestF[neighborIdx] {
            bestF[neighborIdx] = fNew
            openSet.push(vertex: neighborIdx, priority: fNew)
            inOpen[neighborIdx] = true
          }
        }
      }
    }

    return []
  }

  private func midCellChecksum(path: [Cell]) -> UInt32 {
    if path.isEmpty { return 0 }
    let cell = path[path.count / 2]
    return UInt32(cell.x * cell.y)
  }

  func run(iterationId: Int) {
    guard let maze = maze else { return }
    path = astar(start: maze.start, target: maze.finish)
    resultVal = resultVal &+ UInt32(path.count)
  }

  var checksum: UInt32 {
    return resultVal &+ midCellChecksum(path: path)
  }

  func name() -> String {
    return "Maze::AStar"
  }
}
