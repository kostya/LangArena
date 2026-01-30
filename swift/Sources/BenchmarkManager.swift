import Foundation
import CoreFoundation

// Протокол для всех бенчмарков - ТОЧНО как в Kotlin
protocol BenchmarkProtocol: AnyObject {
    func run(iterationId: Int)  // изменено: принимает iterationId
    var checksum: UInt32 { get }  // изменено: возвращает checksum вместо result
    func prepare()
    func warmup()  // новый метод
    func runAll()  // новый метод
}

extension BenchmarkProtocol {
    var iterations: Int {
        // Используем конфиг в формате JSON
        if let config = Helper.config[name] as? [String: Any],
           let iterations = config["iterations"] as? Int {
            return iterations
        }
        return 0
    }
    
    var warmupIterations: Int {
        if let config = Helper.config[name] as? [String: Any],
           let warmup = config["warmup_iterations"] as? Int {
            return warmup
        } else {
            return max(Int(Double(iterations) * 0.2), 1)
        }
    }
    
    var expectedChecksum: Int64 {
        if let config = Helper.config[name] as? [String: Any],
           let checksum = config["checksum"] as? Int64 {
            return checksum
        }
        return 0
    }
    
    // Получение значения конфига
    func configValue<T>(_ field: String) -> T? {
        if let config = Helper.config[name] as? [String: Any] {
            return config[field] as? T
        }
        return nil
    }
    
    var name: String {
        return String(describing: type(of: self))
    }
    
    func prepare() {
        // optional override - как в Kotlin
    }
    
    func warmup() {
        for i in 0..<warmupIterations {
            run(iterationId: i)
        }
    }
    
    func runAll() {
        for i in 0..<iterations {
            run(iterationId: i)
        }
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
        
        // Выводим время начала
        let now = Date().timeIntervalSince1970 * 1000
        print("start: \(Int64(now))")
        
        for factory in benchmarks {
            let bench = factory()
            let className = bench.name
            
            // Пропускаем абстрактные классы как в Kotlin
            if className == "SortBenchmark" || 
               className == "BufferHashBenchmark" || 
               className == "GraphPathBenchmark" {
                continue
            }
            
            // Проверяем, нужно ли запускать этот бенчмарк
            let shouldRun: Bool
            if let singleBench = singleBench {
                // Частичное совпадение (case-insensitive) как в C++
                shouldRun = className.lowercased().contains(singleBench.lowercased())
            } else {
                shouldRun = true
            }
            
            // Проверяем наличие конфигурации
            let hasConfig = Helper.config[className] != nil
            
            if shouldRun && hasConfig {
                print("\(className): ", terminator: "")
                
                Helper.reset()
                
                bench.prepare()
                bench.warmup()
                
                Helper.reset()
                
                let startTime = DispatchTime.now()
                bench.runAll()  // используем runAll вместо run
                let endTime = DispatchTime.now()

                let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
                let timeDelta = Double(nanoTime) / 1_000_000_000.0

                results[className] = timeDelta
                
                // Проверяем checksum вместо result
                let expected = UInt32(truncatingIfNeeded: Int64(bench.expectedChecksum))
                let actual = bench.checksum
                
                if actual == expected {
                    print("OK ", terminator: "")
                    ok += 1
                } else {
                    print("ERR[actual=\(actual), expected=\(expected)] ", terminator: "")
                    fails += 1
                }
                
                print(String(format: "in %.3fs", timeDelta))
                summaryTime += timeDelta
                
                // Небольшая пауза как в Kotlin
                usleep(1000)
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
