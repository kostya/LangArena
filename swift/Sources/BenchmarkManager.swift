import Foundation
import CoreFoundation

// Протокол для всех бенчмарков - ТОЧНО как в Kotlin
protocol BenchmarkProtocol: AnyObject {
    func run()  // this is only method which time measured
    var result: Int64 { get }
    func prepare()
}

extension BenchmarkProtocol {
    var iterations: Int {
        let className = String(describing: type(of: self))
        // ТОЧНО как в Kotlin: пробуем преобразовать в Int, иначе 0
        return Int(Helper.getInput(className)) ?? 0
    }
    
    func prepare() {
        // optional override - как в Kotlin
    }
}

// Менеджер бенчмарков
class BenchmarkManager {
    private static var benchmarks: [() -> BenchmarkProtocol] = []
    
    static func register(_ factory: @escaping () -> BenchmarkProtocol) {
        benchmarks.append(factory)
    }
    
    static func run(singleBench: String? = nil) {
        var results: [String: Double] = [:]
        var summaryTime: Double = 0
        var ok = 0
        var fails = 0
                
        for factory in benchmarks {
            let bench = factory()
            let className = String(describing: type(of: bench))
            
            // Пропускаем абстрактные классы как в Kotlin
            if className == "SortBenchmark" || 
               className == "BufferHashBenchmark" || 
               className == "GraphPathBenchmark" {
                continue
            }
            
            let shouldRun = singleBench == nil || singleBench == className
            
            // В Kotlin проверяется iterations > 0
            // Но для BrainfuckHashMap iterations будет 0 (т.к. input - текст, не число)
            // Поэтому будем запускать если есть запись в конфиге
            
            let hasConfig = Helper.input[className] != nil
            
            if shouldRun && hasConfig {
                print("\(className): ", terminator: "")
                
                Helper.reset()
                
                bench.prepare()
                
                let startTime = DispatchTime.now()
                bench.run()
                let endTime = DispatchTime.now()

                let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
                let timeDelta = Double(nanoTime) / 1_000_000_000.0

                results[className] = timeDelta
                
                // Небольшая пауза как в Kotlin
                usleep(1000)
                
                let expected = Helper.expect[className] ?? 0
                if bench.result == expected {
                    print("OK ", terminator: "")
                    ok += 1
                } else {
                    print("ERR[actual=\(bench.result), expected=\(expected)] ", terminator: "")
                    fails += 1
                }
                
                print(String(format: "in %.3fs", timeDelta))
                summaryTime += timeDelta
            } else if shouldRun {
                print("\n[\(className)]: SKIP - no config entry", terminator: "")
            }
        }
        
        // Запись результатов в файл как в Kotlin
        let jsonResults = results.map { "\"\($0.key)\": \($0.value)" }.joined(separator: ", ")
        let jsonString = "{\(jsonResults)}"
        
        do {
            try jsonString.write(toFile: "/tmp/results.js", atomically: true, encoding: .utf8)
        } catch {
            fputs("Failed to write results: \(error)\n", stderr)
        }
        
        print(String(format: "Summary: %.4fs, %d, %d, %d", summaryTime, ok + fails, ok, fails))
        
        if fails > 0 {
            exit(1)
        }
    }
}

// Алиас для удобства (как в Kotlin: Benchmark - это и протокол, и менеджер)
typealias Benchmark = BenchmarkManager