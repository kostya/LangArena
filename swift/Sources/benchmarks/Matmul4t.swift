import Foundation
import Dispatch

final class Matmul4T: BenchmarkProtocol {
    private var n: Int = 0
    private var _result: UInt32 = 0
    private let lock = NSLock()
    
    init() {
        n = iterations
    }
    
    private func matgen(_ n: Int) -> [[Double]] {
        let tmp = 1.0 / Double(n) / Double(n)
        var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                a[i][j] = tmp * Double(i - j) * Double(i + j)
            }
        }
        return a
    }
    
    private func matmulParallel(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        let size = a.count
        
        // Транспонируем b
        var bT = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        for i in 0..<size {
            for j in 0..<size {
                bT[j][i] = b[i][j]
            }
        }
        
        // Умножение матриц
        var c = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)
        
        // Используем 4 потока явно
        let numThreads = 4
        let rowsPerThread = (size + numThreads - 1) / numThreads
        
        DispatchQueue.concurrentPerform(iterations: numThreads) { threadId in
            let startRow = threadId * rowsPerThread
            let endRow = min(startRow + rowsPerThread, size)
            
            for i in startRow..<endRow {
                let ai = a[i]
                var row = [Double](repeating: 0.0, count: size)
                
                for j in 0..<size {
                    var sum = 0.0
                    let bTj = bT[j]
                    
                    for k in 0..<size {
                        sum += ai[k] * bTj[k]
                    }
                    
                    row[j] = sum
                }
                
                // Синхронизация записи
                lock.lock()
                c[i] = row
                lock.unlock()
            }
        }
        
        return c
    }
    
    func run() {
        let a = matgen(n)
        let b = matgen(n)
        let c = matmulParallel(a, b)
        let center = c[n / 2][n / 2]
        _result = Helper.checksumF64(center)
    }
    
    var result: Int64 {
        return Int64(_result)
    }
    
    func prepare() {}
}