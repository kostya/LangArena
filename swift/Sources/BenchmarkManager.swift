import CoreFoundation
import Foundation

protocol BenchmarkProtocol: AnyObject {
  func run(iterationId: Int)
  var checksum: UInt32 { get }
  func prepare()
  func warmup()
  func runAll()
  func name() -> String
}

extension BenchmarkProtocol {
  var iterations: Int {
    if let config = Helper.config[name()] as? [String: Any],
      let iterations = config["iterations"] as? Int
    {
      return iterations
    }
    return 0
  }

  var warmupIterations: Int {
    if let config = Helper.config[name()] as? [String: Any],
      let warmup = config["warmup_iterations"] as? Int
    {
      return warmup
    } else {
      return max(Int(Double(iterations) * 0.2), 1)
    }
  }

  var expectedChecksum: Int64 {
    if let config = Helper.config[name()] as? [String: Any],
      let checksum = config["checksum"] as? Int64
    {
      return checksum
    }
    return 0
  }

  func configValue<T>(_ field: String) -> T? {
    if let config = Helper.config[name()] as? [String: Any] {
      return config[field] as? T
    }
    return nil
  }

  func name() -> String {
    return String(describing: type(of: self))
  }

  func prepare() {

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

class BenchmarkManager {

  private static var benchmarkMap: [String: () -> BenchmarkProtocol] = [:]

  static func register(_ name: String, factory: @escaping () -> BenchmarkProtocol) {
    benchmarkMap[name] = factory
  }

  static func register(_ factory: @escaping () -> BenchmarkProtocol) {
    let bench = factory()
    let name = bench.name()
    benchmarkMap[name] = factory
  }

  static func run(singleBench: String? = nil) {
    var summaryTime: Double = 0
    var ok = 0
    var fails = 0

    let now = Date().timeIntervalSince1970 * 1000
    print("start: \(Int64(now))")

    for benchName in Helper.order {
      let shouldRun: Bool
      if let singleBench = singleBench {
        shouldRun = benchName.lowercased().contains(singleBench.lowercased())
      } else {
        shouldRun = true
      }

      if !shouldRun {
        continue
      }

      guard let factory = benchmarkMap[benchName] else {
        print("Warning: Benchmark '\(benchName)' defined in config but not found in code")
        continue
      }

      print("\(benchName): ", terminator: "")

      let bench = factory()

      Helper.reset()

      bench.prepare()
      bench.warmup()

      Helper.reset()

      let startTime = DispatchTime.now()
      bench.runAll()
      let endTime = DispatchTime.now()

      let nanoTime = endTime.uptimeNanoseconds - startTime.uptimeNanoseconds
      let timeDelta = Double(nanoTime) / 1_000_000_000.0

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

      usleep(1000)
    }

    print(String(format: "Summary: %.4fs, %d, %d, %d", summaryTime, ok + fails, ok, fails))

    if fails > 0 {
      exit(1)
    }
  }
}

typealias Benchmark = BenchmarkManager
