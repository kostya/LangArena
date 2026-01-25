import Foundation

final class Revcomp: BenchmarkProtocol {
    private var input: String = ""
    private var output: String = ""
    
    // Статическая таблица перевода (как в C++)
    private static var lookupTable: [UInt8] = {
        var table = [UInt8](repeating: 0, count: 256)
        
        // Инициализируем таблицу
        for i in 0..<256 {
            table[i] = UInt8(i) // по умолчанию тот же символ
        }
        
        let from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN"
        let to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN"
        
        let fromBytes = from.utf8.map { $0 }
        let toBytes = to.utf8.map { $0 }
        
        for i in 0..<min(fromBytes.count, toBytes.count) {
            let index = Int(fromBytes[i])
            if index < 256 {
                table[index] = toBytes[i]
            }
        }
        
        return table
    }()
    
    func prepare() {
        output = ""
        // Используем Fasta для генерации данных
        let fasta = Fasta()
        fasta.n = iterations
        fasta.prepare()
        fasta.run()
        // Получаем вывод из Fasta
        input = fasta.getOutput()
    }
    
    private func revcomp(_ seq: String) -> String {
        // Конвертируем в UTF8 байты для быстрой работы
        let bytes = Array(seq.utf8)
        let count = bytes.count
        
        // Создаем массив для результата
        var resultBytes = [UInt8](repeating: 0, count: count)
        let lookup = Self.lookupTable
        
        // Реверсируем и переводим за один проход
        for i in 0..<count {
            let sourceByte = bytes[count - 1 - i] // реверс
            resultBytes[i] = lookup[Int(sourceByte)]
        }
        
        // Форматируем по 60 символов в строку
        var result = ""
        var lineStart = 0
        
        while lineStart < count {
            let lineEnd = min(lineStart + 60, count)
            let lineBytes = resultBytes[lineStart..<lineEnd]
            
            // Быстрое создание строки из байтов
            if let line = String(bytes: lineBytes, encoding: .utf8) {
                result.append(line)
            }
            result.append("\n")
            
            lineStart = lineEnd
        }
        
        return result
    }
    
    func run() {
        var result = ""
        var currentSeq = ""
        
        // Быстрый парсинг строк
        input.enumerateLines { [self] line, _ in  // Явный захват self
            if line.hasPrefix(">") {
                // Обрабатываем предыдущую последовательность если есть
                if !currentSeq.isEmpty {
                    result.append(self.revcomp(currentSeq))  // Явный self
                    currentSeq = ""
                }
                result.append(line)
                result.append("\n")
            } else {
                // Добавляем к текущей последовательности
                currentSeq.append(line)
            }
        }
        
        // Обрабатываем последнюю последовательность
        if !currentSeq.isEmpty {
            result.append(self.revcomp(currentSeq))  // Явный self
        }
        
        output = result
    }
    
    var result: Int64 {
        let checksum = Helper.checksum(output)
        return Int64(bitPattern: UInt64(checksum))
    }
}