import Foundation
import SwiftCSV

final class CsvParse: BenchmarkProtocol {
  private var rows: Int = 0
  private var data: String = ""
  private var resultVal: UInt32 = 0

  init() {
    self.rows = Int(configValue("rows") ?? 0)
  }

  func prepare() {
    var lines: [String] = []
    lines.reserveCapacity(rows)
    lines.append("name,x,z,options,y")

    for i in 0..<rows {
      let asciiValue = UInt8(65 + (i % 26))
      let c = Character(UnicodeScalar(asciiValue))
      let x = Helper.nextFloat(max: 1.0)
      let z = Helper.nextFloat(max: 1.0)
      let y = Helper.nextFloat(max: 1.0)
      var line = "\"point \(c)\\n, \"\"\(i % 100)\"\"\","
      line += String(format: "%.10f,", x)
      line += ","
      line += String(format: "%.10f,", z)
      let flag = i % 2 == 0 ? "true" : "false"
      line += "\"[\(flag)\\n, \(i % 100)]\","
      line += String(format: "%.10f", y)
      lines.append(line)
    }

    data = lines.joined(separator: "\n")
  }

  struct Point {
    let x: Double
    let y: Double
    let z: Double
  }

  func run(iterationId: Int) {
    do {
      let csv = try CSV<Enumerated>(string: data, delimiter: ",", loadColumns: false)

      var points: [Point] = []

      for row in csv.rows {
        if let x = Double(row[1]),
          let z = Double(row[3]),
          let y = Double(row[5])
        {
          points.append(Point(x: x, y: y, z: z))
        }
      }

      if points.isEmpty { return }

      var xSum = 0.0
      var ySum = 0.0
      var zSum = 0.0
      for p in points {
        xSum += p.x
        ySum += p.y
        zSum += p.z
      }

      let count = Double(points.count)
      let xAvg = xSum / count
      let yAvg = ySum / count
      let zAvg = zSum / count

      resultVal &+= Helper.checksumF64(xAvg) &+ Helper.checksumF64(yAvg) &+ Helper.checksumF64(zAvg)

    } catch {
      print("CSV parsing error: \(error)")
    }
  }

  var checksum: UInt32 { return resultVal }
  func name() -> String { return "CSV::Parse" }
}
