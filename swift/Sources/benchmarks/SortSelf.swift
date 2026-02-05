import Foundation

final class SortSelf: SortBenchmark {
    override init() {
        super.init()
    }

    override var name: String { return "SortSelf" }

    override func test() -> [Int] {
        return data.sorted()
    }
}