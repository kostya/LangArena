import Foundation
import Dispatch

final class Matmul16T: Matmul4T {
    override init() {
        super.init()
        n = configValue("n") ?? 0
    }

    override var name: String { return "Matmul16T" }

    override func getNumThreads() -> Int {
        return 16
    }
}