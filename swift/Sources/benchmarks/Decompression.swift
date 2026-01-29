final class Decompression: Compression {
    private var compressedData: CompressedData?
    private var decompressed: [UInt8] = []
    
    override init() {
        super.init()
    }
    
    // УБРАТЬ эту строку полностью, так как name уже определен в протоколе
    // override var name: String { return "Decompression" }
    
    override func prepare() {
        testData = generateTestData(sizeVal)
        compressedData = compress(testData)
    }
    
    override func run(iterationId: Int) {
        decompressed = decompress(compressedData!)
        resultVal &+= UInt32(decompressed.count)
    }
    
    override var checksum: UInt32 {
        var res = resultVal
        if testData == decompressed {
            res &+= 1000000
        }
        return res
    }
}