import Foundation

final class SortSelf: SortBenchmark {
    override func test() -> [Int] {
        // Используем встроенную сортировку Swift
        return data.sorted()
    }
}