import Dispatch
import Foundation

final class Matmul8T: Matmul4T {
  override init() {
    super.init()
    n = configValue("n") ?? 0
  }

  override func getNumThreads() -> Int {
    return 8
  }

  override func name() -> String {
    return "Matmul::T8"
  }
}
