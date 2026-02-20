final class BWTHuffDecode: BWTHuffEncode {
  private var compressedData: CompressedData?
  private var decompressed: [UInt8] = []

  override init() {
    super.init()
  }

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
      res &+= 1_000_000
    }
    return res
  }
}
