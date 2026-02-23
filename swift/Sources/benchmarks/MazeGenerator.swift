import Foundation

final class MazeGenerator: BenchmarkProtocol {
  enum MazeCell {
    case wall
    case path
  }

  class Maze {
    private let width: Int
    private let height: Int
    private var cells: [[MazeCell]]

    init(width: Int, height: Int) {

      let safeWidth = max(width, 5)
      let safeHeight = max(height, 5)
      self.width = safeWidth
      self.height = safeHeight
      self.cells = Array(
        repeating: Array(repeating: .wall, count: safeWidth),
        count: safeHeight)
    }

    subscript(x: Int, y: Int) -> MazeCell {
      get {
        guard x >= 0 && x < width && y >= 0 && y < height else {
          return .wall
        }
        return cells[y][x]
      }
      set {
        guard x >= 0 && x < width && y >= 0 && y < height else { return }
        cells[y][x] = newValue
      }
    }

    private func addRandomPaths() {
      let numExtraPaths = (width * height) / 20

      for _ in 0..<numExtraPaths {

        guard width > 2 && height > 2 else { continue }

        let x = Helper.nextInt(max: width - 2) + 1
        let y = Helper.nextInt(max: height - 2) + 1

        guard x > 0 && x < width - 1 && y > 0 && y < height - 1 else { continue }

        if self[x, y] == .wall && self[x - 1, y] == .wall && self[x + 1, y] == .wall
          && self[x, y - 1] == .wall && self[x, y + 1] == .wall
        {
          self[x, y] = .path
        }
      }
    }

    private func divide(x1: Int, y1: Int, x2: Int, y2: Int) {
      let width = x2 - x1
      let height = y2 - y1

      if width < 2 || height < 2 {
        return
      }

      let widthForWall = max(width - 2, 0)
      let heightForWall = max(height - 2, 0)
      let widthForHole = max(width - 1, 0)
      let heightForHole = max(height - 1, 0)

      if widthForWall == 0 || heightForWall == 0 || widthForHole == 0 || heightForHole == 0 {
        return
      }

      if width > height {

        let wallRange = max(widthForWall / 2, 1)
        let wallOffset = wallRange > 0 ? (Helper.nextInt(max: wallRange)) * 2 : 0
        let wallX = x1 + 2 + wallOffset

        let holeRange = max(heightForHole / 2, 1)
        let holeOffset = holeRange > 0 ? (Helper.nextInt(max: holeRange)) * 2 : 0
        let holeY = y1 + 1 + holeOffset

        guard wallX >= x1 + 2 && wallX <= x2 else { return }
        guard holeY >= y1 + 1 && holeY <= y2 else { return }

        for y in y1...y2 {
          if y != holeY {
            self[wallX, y] = .wall
          }
        }

        if wallX > x1 + 1 {
          divide(x1: x1, y1: y1, x2: wallX - 1, y2: y2)
        }
        if wallX + 1 < x2 {
          divide(x1: wallX + 1, y1: y1, x2: x2, y2: y2)
        }
      } else {

        let wallRange = max(heightForWall / 2, 1)
        let wallOffset = wallRange > 0 ? (Helper.nextInt(max: wallRange)) * 2 : 0
        let wallY = y1 + 2 + wallOffset

        let holeRange = max(widthForHole / 2, 1)
        let holeOffset = holeRange > 0 ? (Helper.nextInt(max: holeRange)) * 2 : 0
        let holeX = x1 + 1 + holeOffset

        guard wallY >= y1 + 2 && wallY <= y2 else { return }
        guard holeX >= x1 + 1 && holeX <= x2 else { return }

        for x in x1...x2 {
          if x != holeX {
            self[x, wallY] = .wall
          }
        }

        if wallY > y1 + 1 {
          divide(x1: x1, y1: y1, x2: x2, y2: wallY - 1)
        }
        if wallY + 1 < y2 {
          divide(x1: x1, y1: wallY + 1, x2: x2, y2: y2)
        }
      }
    }

    private func isConnected(startX: Int, startY: Int, goalX: Int, goalY: Int) -> Bool {

      guard startX >= 0 && startX < width && startY >= 0 && startY < height else {
        return false
      }
      guard goalX >= 0 && goalX < width && goalY >= 0 && goalY < height else {
        return false
      }

      var visited = Array(
        repeating: Array(repeating: false, count: width),
        count: height)
      var queue: [(x: Int, y: Int)] = [(startX, startY)]
      visited[startY][startX] = true

      while !queue.isEmpty {
        let (x, y) = queue.removeFirst()

        if x == goalX && y == goalY {
          return true
        }

        let directions = [(0, -1), (1, 0), (0, 1), (-1, 0)]

        for (dx, dy) in directions {
          let nx = x + dx
          let ny = y + dy

          guard nx >= 0 && nx < width && ny >= 0 && ny < height else {
            continue
          }

          if self[nx, ny] == .path && !visited[ny][nx] {
            visited[ny][nx] = true
            queue.append((nx, ny))
          }
        }
      }

      return false
    }

    func generate() {
      if width < 5 || height < 5 {

        let midY = height / 2
        for x in 0..<width {
          self[x, midY] = .path
        }
        return
      }

      divide(x1: 0, y1: 0, x2: width - 1, y2: height - 1)
      addRandomPaths()
    }

    func toBoolGrid() -> [[Bool]] {
      var result = Array(
        repeating: Array(repeating: false, count: width),
        count: height)
      for y in 0..<height {
        for x in 0..<width {
          result[y][x] = (self[x, y] == .path)
        }
      }
      return result
    }

    static func generateWalkableMaze(width: Int, height: Int) -> [[Bool]] {
      let maze = Maze(width: width, height: height)
      maze.generate()

      let startX = 1
      let startY = 1
      let goalX = width - 2
      let goalY = height - 2

      if width >= 3 && height >= 3 {
        if !maze.isConnected(
          startX: startX, startY: startY,
          goalX: goalX, goalY: goalY)
        {

          for x in 0..<width {
            for y in 0..<height {
              if x == 1 || y == 1 || x == width - 2 || y == height - 2 {
                maze[x, y] = .path
              }
            }
          }
        }
      }

      return maze.toBoolGrid()
    }
  }

  private var resultVal: UInt32 = 0
  private var width: Int = 0
  private var height: Int = 0
  private var boolGrid: [[Bool]] = []

  init() {

    let configW = Int(configValue("w") ?? 50)
    let configH = Int(configValue("h") ?? 50)
    self.width = max(configW, 5)
    self.height = max(configH, 5)
  }

  private func gridChecksum(_ grid: [[Bool]]) -> UInt32 {
    var hasher: UInt32 = 2_166_136_261
    let prime: UInt32 = 16_777_619

    for y in 0..<grid.count {
      let row = grid[y]
      for x in 0..<row.count {
        if row[x] {

          let x32 = UInt32(x)
          let jSquared = x32 &* x32

          hasher = hasher ^ jSquared
          hasher = hasher &* prime
        }
      }
    }
    return hasher
  }

  func run(iterationId: Int) {
    boolGrid = Maze.generateWalkableMaze(width: width, height: height)
  }

  var checksum: UInt32 {
    return gridChecksum(boolGrid)
  }

  func prepare() {

  }

  func name() -> String {
    return "MazeGenerator"
  }
}
