module benchmarks.compress;

import benchmark;
import helper;
import std.stdio;
import std.algorithm : sort;
import std.array;
import std.range;
import std.typecons;

ubyte[] generateTestData(long size)
{
    string pattern = "ABRACADABRA";
    ubyte[] data = new ubyte[cast(size_t) size];

    foreach (i; 0 .. size)
    {
        data[cast(size_t) i] = cast(ubyte) pattern[i % pattern.length];
    }

    return data;
}

class BWTEncode : Benchmark
{
public:
    struct BWTResult
    {
        ubyte[] transformed;
        int originalIdx;

        this(ubyte[] t, int idx)
        {
            transformed = t;
            originalIdx = idx;
        }
    }

private:
    BWTResult bwtTransform(const ubyte[] input)
    {
        size_t n = input.length;
        if (n == 0)
            return BWTResult([], 0);

        auto sa = new size_t[n];
        foreach (i; 0 .. n)
            sa[i] = i;

        size_t[256] bucketSizes = 0;
        size_t[256] bucketStarts;

        foreach (idx; sa)
        {
            bucketSizes[input[idx]]++;
        }

        size_t total = 0;
        foreach (i; 0 .. 256)
        {
            bucketStarts[i] = total;
            total += bucketSizes[i];
            bucketSizes[i] = 0;
        }

        auto tempSA = new size_t[n];
        foreach (idx; sa)
        {
            ubyte c = input[idx];
            size_t pos = bucketStarts[c] + bucketSizes[c];
            tempSA[pos] = idx;
            bucketSizes[c]++;
        }
        sa = tempSA;

        if (n > 1)
        {
            auto rank = new int[n];
            int currentRank = 0;
            ubyte prevChar = input[sa[0]];

            foreach (i; 0 .. n)
            {
                size_t idx = sa[i];
                ubyte currChar = input[idx];
                if (currChar != prevChar)
                {
                    currentRank++;
                    prevChar = currChar;
                }
                rank[idx] = currentRank;
            }

            size_t k = 1;
            while (k < n)
            {
                struct Pair
                {
                    int first, second;
                }

                auto pairs = new Pair[n];
                foreach (i; 0 .. n)
                {
                    pairs[i] = Pair(rank[i], rank[(i + k) % n]);
                }

                sort!((a, b) {
                    if (pairs[a].first != pairs[b].first)
                        return pairs[a].first < pairs[b].first;
                    return pairs[a].second < pairs[b].second;
                })(sa);

                auto newRank = new int[n];
                newRank[sa[0]] = 0;
                foreach (i; 1 .. n)
                {
                    auto prevPair = pairs[sa[i - 1]];
                    auto currPair = pairs[sa[i]];
                    newRank[sa[i]] = newRank[sa[i - 1]] + ((prevPair.first != currPair.first
                            || prevPair.second != currPair.second) ? 1 : 0);
                }

                rank = newRank;
                k *= 2;
            }
        }

        auto transformed = new ubyte[n];
        int originalIdx = 0;

        foreach (i; 0 .. n)
        {
            size_t suffix = sa[i];
            if (suffix == 0)
            {
                transformed[i] = input[n - 1];
                originalIdx = cast(int) i;
            }
            else
            {
                transformed[i] = input[suffix - 1];
            }
        }

        return BWTResult(transformed, originalIdx);
    }

public:
    long sizeVal;
    ubyte[] testData;
    BWTResult bwtResult;
    uint resultVal;

    this()
    {
        resultVal = 0;
        bwtResult = BWTResult([], 0);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::BWTEncode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);
    }

    override void run(int iterationId)
    {
        bwtResult = bwtTransform(testData);
        resultVal += cast(uint) bwtResult.transformed.length;
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class BWTDecode : Benchmark
{
private:
    ubyte[] bwtInverse(const BWTEncode.BWTResult bwtResult)
    {
        auto bwt = bwtResult.transformed;
        size_t n = bwt.length;
        if (n == 0)
            return [];

        int[256] counts = 0;
        foreach (b; bwt)
            counts[b]++;

        int[256] positions = 0;
        int total = 0;
        foreach (i; 0 .. 256)
        {
            positions[i] = total;
            total += counts[i];
        }

        auto next = new size_t[n];
        int[256] tempCounts = 0;

        foreach (i; 0 .. n)
        {
            ubyte byteIdx = bwt[i];
            size_t pos = positions[byteIdx] + tempCounts[byteIdx];
            next[pos] = i;
            tempCounts[byteIdx]++;
        }

        auto result = new ubyte[n];
        size_t idx = bwtResult.originalIdx;

        foreach (i; 0 .. n)
        {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

public:
    long sizeVal;
    ubyte[] testData;
    ubyte[] inverted;
    BWTEncode.BWTResult bwtResult;
    uint resultVal;

    this()
    {
        resultVal = 0;
        bwtResult = BWTEncode.BWTResult([], 0);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::BWTDecode";
    }

    override void prepare()
    {
        auto encoder = new BWTEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        testData = encoder.testData;
        bwtResult = encoder.bwtResult;
    }

    override void run(int iterationId)
    {
        inverted = bwtInverse(bwtResult);
        resultVal += cast(uint) inverted.length;
    }

    override uint checksum()
    {
        uint res = resultVal;
        if (inverted == testData)
            res += 100000;
        return res;
    }
}

class HuffEncode : Benchmark
{
public:
    static class HuffmanNode
    {
    public:
        int frequency;
        ubyte byteVal;
        bool isLeaf;
        HuffmanNode left;
        HuffmanNode right;

        this(int freq, ubyte val = 0, bool leaf = true)
        {
            frequency = freq;
            byteVal = val;
            isLeaf = leaf;
            left = null;
            right = null;
        }
    }

    struct HuffmanCodes
    {
        int[256] codeLengths;
        int[256] codes;
    }

    struct EncodedResult
    {
        ubyte[] data;
        int bitCount;
        int[256] frequencies;
    }

private:
    static HuffmanNode buildHuffmanTree(const int[256] frequencies)
    {
        auto nodes = new HuffmanNode[256];
        size_t nodeCount = 0;

        foreach (i; 0 .. 256)
        {
            if (frequencies[i] > 0)
            {
                nodes[nodeCount++] = new HuffmanNode(frequencies[i], cast(ubyte) i);
            }
        }

        nodes = nodes[0 .. nodeCount].dup;
        sort!((a, b) => a.frequency < b.frequency)(nodes);

        if (nodeCount == 1)
        {
            auto node = nodes[0];
            auto root = new HuffmanNode(node.frequency, 0, false);
            root.left = node;
            root.right = new HuffmanNode(0, 0);
            return root;
        }

        while (nodeCount > 1)
        {
            auto left = nodes[0];
            auto right = nodes[1];

            foreach (i; 2 .. nodeCount)
                nodes[i - 2] = nodes[i];
            nodeCount -= 2;

            auto parent = new HuffmanNode(left.frequency + right.frequency, 0, false);
            parent.left = left;
            parent.right = right;

            size_t pos = 0;
            while (pos < nodeCount && nodes[pos].frequency < parent.frequency)
                pos++;

            foreach_reverse (i; pos .. nodeCount)
                nodes[i + 1] = nodes[i];
            nodes[pos] = parent;
            nodeCount++;
        }

        return nodes[0];
    }

    static void buildHuffmanCodes(HuffmanNode node, int code, int length, ref HuffmanCodes codes)
    {
        if (node.isLeaf)
        {
            if (length > 0 || node.byteVal != 0)
            {
                int idx = node.byteVal;
                codes.codeLengths[idx] = length;
                codes.codes[idx] = code;
            }
        }
        else
        {
            if (node.left !is null)
                buildHuffmanCodes(node.left, code << 1, length + 1, codes);
            if (node.right !is null)
                buildHuffmanCodes(node.right, (code << 1) | 1, length + 1, codes);
        }
    }

    static EncodedResult huffmanEncode(const ubyte[] data,
            const HuffmanCodes codes, const int[256] frequencies)
    {
        auto result = appender!(ubyte[])();
        result.reserve(data.length * 2);

        ubyte currentByte = 0;
        int bitPos = 0;
        int totalBits = 0;

        foreach (b; data)
        {
            int idx = b;
            int code = codes.codes[idx];
            int length = codes.codeLengths[idx];

            for (int i = length - 1; i >= 0; i--)
            {
                if ((code & (1 << i)) != 0)
                    currentByte |= 1 << (7 - bitPos);
                bitPos++;
                totalBits++;

                if (bitPos == 8)
                {
                    result.put(currentByte);
                    currentByte = 0;
                    bitPos = 0;
                }
            }
        }

        if (bitPos > 0)
        {
            result.put(currentByte);
        }

        return EncodedResult(result.data, totalBits, frequencies);
    }

public:
    long sizeVal;
    ubyte[] testData;
    EncodedResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = EncodedResult([], 0, int[256].init);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::HuffEncode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);
    }

    override void run(int iterationId)
    {
        int[256] frequencies = 0;
        foreach (b; testData)
            frequencies[b]++;

        auto tree = buildHuffmanTree(frequencies);

        HuffmanCodes codes;
        buildHuffmanCodes(tree, 0, 0, codes);

        encoded = huffmanEncode(testData, codes, frequencies);
        resultVal += cast(uint) encoded.data.length;
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class HuffDecode : Benchmark
{
private:
    ubyte[] huffmanDecode(const ubyte[] encoded, HuffEncode.HuffmanNode root, int bitCount)
    {

        ubyte[] result = new ubyte[bitCount];
        size_t resultSize = 0;

        auto currentNode = root;
        int bitsProcessed = 0;
        size_t byteIndex = 0;

        while (bitsProcessed < bitCount && byteIndex < encoded.length)
        {
            ubyte byteVal = encoded[byteIndex++];

            for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--)
            {
                bool bit = ((byteVal >> bitPos) & 1) == 1;
                currentNode = bit ? currentNode.right : currentNode.left;
                bitsProcessed++;

                if (currentNode.isLeaf)
                {
                    result[resultSize++] = currentNode.byteVal;
                    currentNode = root;
                }
            }
        }

        return result[0 .. resultSize];
    }

public:
    long sizeVal;
    ubyte[] testData;
    ubyte[] decoded;
    HuffEncode.EncodedResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = HuffEncode.EncodedResult([], 0, int[256].init);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::HuffDecode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);

        auto encoder = new HuffEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    override void run(int iterationId)
    {
        auto tree = HuffEncode.buildHuffmanTree(encoded.frequencies);
        decoded = huffmanDecode(encoded.data, tree, encoded.bitCount);
        resultVal += cast(uint) decoded.length;
    }

    override uint checksum()
    {
        uint res = resultVal;
        if (decoded == testData)
            res += 100000;
        return res;
    }
}

class ArithEncode : Benchmark
{
public:
    struct ArithEncodedResult
    {
        ubyte[] data;
        int bitCount;
        int[256] frequencies;

    }

    class ArithFreqTable
    {
    public:
        int total;
        int[256] low;
        int[256] high;

        this(const int[256] frequencies)
        {
            total = 0;
            foreach (f; frequencies)
                total += f;

            int cum = 0;
            foreach (i; 0 .. 256)
            {
                low[i] = cum;
                cum += frequencies[i];
                high[i] = cum;
            }
        }
    }

    class BitOutputStream
    {
    private:
        int buffer = 0;
        int bitPos = 0;
        ubyte[] bytes;
        int bitsWritten = 0;

    public:
        void writeBit(int bit)
        {
            buffer = (buffer << 1) | (bit & 1);
            bitPos++;
            bitsWritten++;

            if (bitPos == 8)
            {
                bytes ~= cast(ubyte) buffer;
                buffer = 0;
                bitPos = 0;
            }
        }

        ubyte[] flush()
        {
            if (bitPos > 0)
            {
                buffer <<= (8 - bitPos);
                bytes ~= cast(ubyte) buffer;
            }
            return bytes;
        }

        int getBitsWritten()
        {
            return bitsWritten;
        }
    }

private:
    ArithEncodedResult arithEncode(const ubyte[] data)
    {
        int[256] frequencies = 0;
        foreach (b; data)
            frequencies[b]++;

        auto freqTable = new ArithFreqTable(frequencies);

        ulong low = 0;
        ulong high = 0xFFFFFFFF;
        int pending = 0;
        auto output = new BitOutputStream();

        foreach (b; data)
        {
            int idx = b;
            ulong range = high - low + 1;

            high = low + (range * freqTable.high[idx] / freqTable.total) - 1;
            low = low + (range * freqTable.low[idx] / freqTable.total);

            while (true)
            {
                if (high < 0x80000000)
                {
                    output.writeBit(0);
                    foreach (_; 0 .. pending)
                        output.writeBit(1);
                    pending = 0;
                }
                else if (low >= 0x80000000)
                {
                    output.writeBit(1);
                    foreach (_; 0 .. pending)
                        output.writeBit(0);
                    pending = 0;
                    low -= 0x80000000;
                    high -= 0x80000000;
                }
                else if (low >= 0x40000000 && high < 0xC0000000)
                {
                    pending++;
                    low -= 0x40000000;
                    high -= 0x40000000;
                }
                else
                {
                    break;
                }

                low <<= 1;
                high = (high << 1) | 1;
                high &= 0xFFFFFFFF;
            }
        }

        pending++;
        if (low < 0x40000000)
        {
            output.writeBit(0);
            foreach (_; 0 .. pending)
                output.writeBit(1);
        }
        else
        {
            output.writeBit(1);
            foreach (_; 0 .. pending)
                output.writeBit(0);
        }

        return ArithEncodedResult(output.flush(), output.getBitsWritten(), frequencies);
    }

public:
    long sizeVal;
    ubyte[] testData;
    ArithEncodedResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = ArithEncodedResult([], 0, int[256].init);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::ArithEncode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);
    }

    override void run(int iterationId)
    {
        encoded = arithEncode(testData);
        resultVal += cast(uint) encoded.data.length;
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class ArithDecode : Benchmark
{
public:
    class BitInputStream
    {
    private:
        const(ubyte)[] bytes;
        size_t bytePos = 0;
        int bitPos = 0;
        ubyte currentByte;

    public:
        this(const(ubyte)[] b)
        {
            bytes = b;
            currentByte = bytes.length > 0 ? bytes[0] : 0;
        }

        int readBit()
        {
            if (bitPos == 8)
            {
                bytePos++;
                bitPos = 0;
                currentByte = bytePos < bytes.length ? bytes[bytePos] : 0;
            }

            int bit = (currentByte >> (7 - bitPos)) & 1;
            bitPos++;
            return bit;
        }
    }

private:
    ubyte[] arithDecode(const ArithEncode.ArithEncodedResult encoded)
    {
        auto frequencies = encoded.frequencies;
        int total = 0;
        foreach (f; frequencies)
            total += f;
        int dataSize = total;

        int[256] lowTable = void;
        int[256] highTable = void;
        int cum = 0;
        foreach (i; 0 .. 256)
        {
            lowTable[i] = cum;
            cum += frequencies[i];
            highTable[i] = cum;
        }

        auto result = new ubyte[dataSize];
        auto input = new BitInputStream(encoded.data);

        ulong value = 0;
        foreach (_; 0 .. 32)
            value = (value << 1) | input.readBit();

        ulong low = 0;
        ulong high = 0xFFFFFFFF;

        foreach (j; 0 .. dataSize)
        {
            ulong range = high - low + 1;
            ulong scaled = ((value - low + 1) * total - 1) / range;

            int symbol = 0;
            while (symbol < 255 && highTable[symbol] <= scaled)
                symbol++;

            result[j] = cast(ubyte) symbol;

            high = low + (range * highTable[symbol] / total) - 1;
            low = low + (range * lowTable[symbol] / total);

            while (true)
            {
                if (high < 0x80000000)
                {

                }
                else if (low >= 0x80000000)
                {
                    value -= 0x80000000;
                    low -= 0x80000000;
                    high -= 0x80000000;
                }
                else if (low >= 0x40000000 && high < 0xC0000000)
                {
                    value -= 0x40000000;
                    low -= 0x40000000;
                    high -= 0x40000000;
                }
                else
                {
                    break;
                }

                low <<= 1;
                high = (high << 1) | 1;
                value = (value << 1) | input.readBit();
            }
        }

        return result;
    }

public:
    long sizeVal;
    ubyte[] testData;
    ubyte[] decoded;
    ArithEncode.ArithEncodedResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = ArithEncode.ArithEncodedResult([], 0, int[256].init);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::ArithDecode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);

        auto encoder = new ArithEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    override void run(int iterationId)
    {
        decoded = arithDecode(encoded);
        resultVal += cast(uint) decoded.length;
    }

    override uint checksum()
    {
        uint res = resultVal;
        if (decoded == testData)
            res += 100000;
        return res;
    }
}

class LZWEncode : Benchmark
{
public:
    struct LZWResult
    {
        ubyte[] data;
        int dictSize;
    }

private:
    LZWResult lzwEncode(const ubyte[] input)
    {
        if (input.length == 0)
            return LZWResult([], 256);

        int[string] dict;
        foreach (i; 0 .. 256)
        {
            dict[cast(string)[cast(char) i]] = i;
        }

        int nextCode = 256;

        auto result = appender!(ubyte[])();
        result.reserve(input.length * 2);

        string current = cast(string)[cast(char) input[0]];

        foreach (i; 1 .. input.length)
        {
            string nextChar = cast(string)[cast(char) input[i]];
            string newStr = current ~ nextChar;

            if (newStr in dict)
            {
                current = newStr;
            }
            else
            {
                int code = dict[current];
                result.put(cast(ubyte)((code >> 8) & 0xFF));
                result.put(cast(ubyte)(code & 0xFF));

                dict[newStr] = nextCode++;
                current = nextChar;
            }
        }

        int lastCode = dict[current];
        result.put(cast(ubyte)((lastCode >> 8) & 0xFF));
        result.put(cast(ubyte)(lastCode & 0xFF));

        return LZWResult(result.data, nextCode);
    }

public:
    long sizeVal;
    ubyte[] testData;
    LZWResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = LZWResult([], 256);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::LZWEncode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);
    }

    override void run(int iterationId)
    {
        encoded = lzwEncode(testData);
        resultVal += cast(uint) encoded.data.length;
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class LZWDecode : Benchmark
{
private:
    ubyte[] lzwDecode(const LZWEncode.LZWResult encoded)
    {
        if (encoded.data.length == 0)
            return [];

        string[] dict;
        dict.reserve(4096);
        foreach (i; 0 .. 256)
        {
            dict ~= cast(string)[cast(char) i];
        }

        auto result = appender!(ubyte[])();
        result.reserve(encoded.data.length * 2);

        auto data = encoded.data;
        size_t pos = 0;

        int high = data[pos];
        int low = data[pos + 1];
        int oldCode = (high << 8) | low;
        pos += 2;

        string oldStr = dict[oldCode];
        result.put(cast(ubyte[]) oldStr);

        int nextCode = 256;

        while (pos < data.length)
        {
            high = data[pos];
            low = data[pos + 1];
            int newCode = (high << 8) | low;
            pos += 2;

            string newStr;
            if (newCode < cast(int) dict.length)
            {
                newStr = dict[newCode];
            }
            else if (newCode == nextCode)
            {
                newStr = dict[oldCode] ~ dict[oldCode][0];
            }
            else
            {
                throw new Exception("Error decode");
            }

            result.put(cast(ubyte[]) newStr);

            dict ~= dict[oldCode] ~ newStr[0];
            nextCode++;

            oldCode = newCode;
        }

        return result.data;
    }

public:
    long sizeVal;
    ubyte[] testData;
    ubyte[] decoded;
    LZWEncode.LZWResult encoded;
    uint resultVal;

    this()
    {
        resultVal = 0;
        encoded = LZWEncode.LZWResult([], 256);
        sizeVal = configVal("size");
    }

    override string className() const
    {
        return "Compress::LZWDecode";
    }

    override void prepare()
    {
        testData = generateTestData(sizeVal);

        auto encoder = new LZWEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    override void run(int iterationId)
    {
        decoded = lzwDecode(encoded);
        resultVal += cast(uint) decoded.length;
    }

    override uint checksum()
    {
        uint res = resultVal;
        if (decoded == testData)
            res += 100000;
        return res;
    }
}
