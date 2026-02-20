import Dispatch
import Foundation

final class Matmul8T: Matmul4T {
  override init() {
    super.init()
    n = configValue("n") ?? 0
  }

  override var name: String { return "Matmul8T" }

  override func getNumThreads() -> Int {
    return 8
  }
}
