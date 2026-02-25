package benchmarks;

import java.util.*;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

class Compress {
    public static byte[] generateTestData(long size) {
        String pattern = "ABRACADABRA";
        byte[] data = new byte[(int) size];
        for (int i = 0; i < size; i++) {
            data[i] = (byte) pattern.charAt(i % pattern.length());
        }
        return data;
    }
}

class BWTEncode extends Benchmark {
    protected long sizeVal;
    protected byte[] testData;
    protected BWTResult bwtResult;
    protected long resultVal;

    public static class BWTResult {
        byte[] transformed;
        int originalIdx;

        BWTResult(byte[] transformed, int originalIdx) {
            this.transformed = transformed;
            this.originalIdx = originalIdx;
        }
    }

    public BWTEncode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::BWTEncode";
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);
    }

    protected BWTResult bwtTransform(byte[] input) {
        int n = input.length;
        if (n == 0) {
            return new BWTResult(new byte[0], 0);
        }

        int[] counts = new int[256];
        for (byte b : input) {
            counts[b & 0xFF]++;
        }

        int[] positions = new int[256];
        int total = 0;
        for (int i = 0; i < 256; i++) {
            positions[i] = total;
            total += counts[i];
        }

        int[] sa = new int[n];
        int[] tempCounts = new int[256];
        for (int i = 0; i < n; i++) {
            int byteIdx = input[i] & 0xFF;
            int pos = positions[byteIdx] + tempCounts[byteIdx];
            sa[pos] = i;
            tempCounts[byteIdx]++;
        }

        if (n > 1) {
            int[] rank = new int[n];
            int currentRank = 0;
            int prevChar = input[sa[0]] & 0xFF;

            for (int i = 0; i < n; i++) {
                int idx = sa[i];
                int currChar = input[idx] & 0xFF;
                if (currChar != prevChar) {
                    currentRank++;
                    prevChar = currChar;
                }
                rank[idx] = currentRank;
            }

            int k = 1;
            while (k < n) {

                Integer[] saObj = new Integer[n];
                for (int i = 0; i < n; i++) saObj[i] = sa[i];

                final int[] rankCopy = rank.clone();
                final int kFinal = k;

                Arrays.sort(saObj, (a, b) -> {
                    int ra = rankCopy[a];
                    int rb = rankCopy[b];
                    if (ra != rb) {
                        return Integer.compare(ra, rb);
                    }
                    int rak = rankCopy[(a + kFinal) % n];
                    int rbk = rankCopy[(b + kFinal) % n];
                    return Integer.compare(rak, rbk);
                });

                for (int i = 0; i < n; i++) sa[i] = saObj[i];

                int[] newRank = new int[n];
                newRank[sa[0]] = 0;
                for (int i = 1; i < n; i++) {
                    int prevIdx = sa[i - 1];
                    int currIdx = sa[i];
                    newRank[currIdx] = newRank[prevIdx] +
                                       (rank[prevIdx] != rank[currIdx] ||
                                        rank[(prevIdx + k) % n] != rank[(currIdx + k) % n] ? 1 : 0);
                }

                rank = newRank;
                k <<= 1;
            }
        }

        byte[] transformed = new byte[n];
        int originalIdx = 0;

        for (int i = 0; i < n; i++) {
            int suffix = sa[i];
            if (suffix == 0) {
                transformed[i] = input[n - 1];
                originalIdx = i;
            } else {
                transformed[i] = input[suffix - 1];
            }
        }

        return new BWTResult(transformed, originalIdx);
    }

    @Override
    public void run(int iterationId) {
        bwtResult = bwtTransform(testData);
        resultVal += bwtResult.transformed.length;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class BWTDecode extends Benchmark {
    private long sizeVal;
    private byte[] testData;
    private byte[] inverted;
    private BWTEncode.BWTResult bwtResult;
    private long resultVal;

    public BWTDecode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::BWTDecode";
    }

    private byte[] bwtInverse(BWTEncode.BWTResult bwtResult) {
        byte[] bwt = bwtResult.transformed;
        int n = bwt.length;
        if (n == 0) return new byte[0];

        int[] counts = new int[256];
        for (byte b : bwt) counts[b & 0xFF]++;

        int[] positions = new int[256];
        int total = 0;
        for (int i = 0; i < 256; i++) {
            positions[i] = total;
            total += counts[i];
        }

        int[] next = new int[n];
        int[] tempCounts = new int[256];

        for (int i = 0; i < n; i++) {
            int byteIdx = bwt[i] & 0xFF;
            int pos = positions[byteIdx] + tempCounts[byteIdx];
            next[pos] = i;
            tempCounts[byteIdx]++;
        }

        byte[] result = new byte[n];
        int idx = bwtResult.originalIdx;

        for (int i = 0; i < n; i++) {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

    @Override
    public void prepare() {
        BWTEncode encoder = new BWTEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        testData = encoder.testData;
        bwtResult = encoder.bwtResult;
    }

    @Override
    public void run(int iterationId) {
        inverted = bwtInverse(bwtResult);
        resultVal += inverted.length;
    }

    @Override
    public long checksum() {
        long res = resultVal;
        if (Arrays.equals(inverted, testData)) {
            res += 100000;
        }
        return res;
    }
}

class HuffEncode extends Benchmark {
    public static class HuffmanNode implements Comparable<HuffmanNode> {
        int frequency;
        byte byteVal;
        boolean isLeaf;
        HuffmanNode left;
        HuffmanNode right;

        HuffmanNode(int frequency, byte byteVal, boolean isLeaf) {
            this.frequency = frequency;
            this.byteVal = byteVal;
            this.isLeaf = isLeaf;
            this.left = null;
            this.right = null;
        }

        HuffmanNode(int frequency, byte byteVal) {
            this(frequency, byteVal, true);
        }

        @Override
        public int compareTo(HuffmanNode other) {
            return Integer.compare(this.frequency, other.frequency);
        }
    }

    public static class HuffmanCodes {
        int[] codeLengths = new int[256];
        int[] codes = new int[256];
    }

    public static class EncodedResult {
        byte[] data;
        int bitCount;
        int[] frequencies;

        EncodedResult(byte[] data, int bitCount, int[] frequencies) {
            this.data = data;
            this.bitCount = bitCount;
            this.frequencies = frequencies;
        }
    }

    public static HuffmanNode buildHuffmanTree(int[] frequencies) {
        List<HuffmanNode> nodes = new ArrayList<>();
        for (int i = 0; i < 256; i++) {
            if (frequencies[i] > 0) {
                nodes.add(new HuffmanNode(frequencies[i], (byte) i));
            }
        }

        nodes.sort(Comparator.comparingInt(a -> a.frequency));

        if (nodes.size() == 1) {
            HuffmanNode node = nodes.get(0);
            HuffmanNode root = new HuffmanNode(node.frequency, (byte) 0, false);
            root.left = node;
            root.right = new HuffmanNode(0, (byte) 0);
            return root;
        }

        while (nodes.size() > 1) {
            HuffmanNode left = nodes.remove(0);
            HuffmanNode right = nodes.remove(0);

            HuffmanNode parent = new HuffmanNode(
                left.frequency + right.frequency,
                (byte) 0, false
            );
            parent.left = left;
            parent.right = right;

            int pos = Collections.binarySearch(nodes, parent,
                                               Comparator.comparingInt(a -> a.frequency));
            if (pos < 0) {
                pos = -pos - 1;
            }
            nodes.add(pos, parent);
        }

        return nodes.get(0);
    }

    public static void buildHuffmanCodes(HuffmanNode node, int code, int length, HuffmanCodes huffmanCodes) {
        if (node.isLeaf) {
            if (length > 0 || node.byteVal != 0) {
                int idx = node.byteVal & 0xFF;
                huffmanCodes.codeLengths[idx] = length;
                huffmanCodes.codes[idx] = code;
            }
        } else {
            if (node.left != null) {
                buildHuffmanCodes(node.left, code << 1, length + 1, huffmanCodes);
            }
            if (node.right != null) {
                buildHuffmanCodes(node.right, (code << 1) | 1, length + 1, huffmanCodes);
            }
        }
    }

    public static EncodedResult huffmanEncode(byte[] data, HuffmanCodes huffmanCodes, int[] frequencies) {
        byte[] result = new byte[data.length * 2];
        int currentByte = 0;
        int bitPos = 0;
        int byteIndex = 0;
        int totalBits = 0;

        for (byte b : data) {
            int idx = b & 0xFF;
            int code = huffmanCodes.codes[idx];
            int length = huffmanCodes.codeLengths[idx];

            for (int i = length - 1; i >= 0; i--) {
                if ((code & (1 << i)) != 0) {
                    currentByte |= 1 << (7 - bitPos);
                }
                bitPos++;
                totalBits++;

                if (bitPos == 8) {
                    if (byteIndex >= result.length) {
                        result = Arrays.copyOf(result, result.length * 2);
                    }
                    result[byteIndex++] = (byte) currentByte;
                    currentByte = 0;
                    bitPos = 0;
                }
            }
        }

        if (bitPos > 0) {
            if (byteIndex >= result.length) {
                result = Arrays.copyOf(result, result.length * 2);
            }
            result[byteIndex++] = (byte) currentByte;
        }

        return new EncodedResult(Arrays.copyOf(result, byteIndex), totalBits, frequencies);
    }

    protected long sizeVal;
    protected byte[] testData;
    protected EncodedResult encoded;
    protected long resultVal;

    public HuffEncode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::HuffEncode";
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);
    }

    @Override
    public void run(int iterationId) {
        int[] frequencies = new int[256];
        for (byte b : testData) {
            frequencies[b & 0xFF]++;
        }

        HuffmanNode tree = buildHuffmanTree(frequencies);

        HuffmanCodes codes = new HuffmanCodes();
        buildHuffmanCodes(tree, 0, 0, codes);

        encoded = huffmanEncode(testData, codes, frequencies);
        resultVal += encoded.data.length;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class HuffDecode extends Benchmark {
    private long sizeVal;
    private byte[] testData;
    private byte[] decoded;
    private HuffEncode.EncodedResult encoded;
    private long resultVal;

    public HuffDecode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::HuffDecode";
    }

    private byte[] huffmanDecode(byte[] encoded, HuffEncode.HuffmanNode root, int bitCount) {

        byte[] result = new byte[bitCount];
        int resultIdx = 0;
        HuffEncode.HuffmanNode current = root;
        int bitsProcessed = 0;
        int byteIndex = 0;

        while (bitsProcessed < bitCount && byteIndex < encoded.length) {
            int byteVal = encoded[byteIndex++] & 0xFF;

            for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--) {
                boolean bit = ((byteVal >> bitPos) & 1) == 1;
                bitsProcessed++;

                current = bit ? current.right : current.left;

                if (current.isLeaf) {
                    result[resultIdx++] = current.byteVal;
                    current = root;
                }
            }
        }

        if (resultIdx < result.length) {
            byte[] finalResult = new byte[resultIdx];
            System.arraycopy(result, 0, finalResult, 0, resultIdx);
            return finalResult;
        }
        return result;
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);

        HuffEncode encoder = new HuffEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    @Override
    public void run(int iterationId) {
        HuffEncode.HuffmanNode tree = HuffEncode.buildHuffmanTree(encoded.frequencies);
        decoded = huffmanDecode(encoded.data, tree, encoded.bitCount);
        resultVal += decoded.length;
    }

    @Override
    public long checksum() {
        long res = resultVal;
        if (Arrays.equals(decoded, testData)) {
            res += 100000;
        }
        return res;
    }
}

class ArithEncode extends Benchmark {
    public static class ArithEncodedResult {
        byte[] data;
        int bitCount;
        int[] frequencies;

        ArithEncodedResult(byte[] data, int bitCount, int[] frequencies) {
            this.data = data;
            this.bitCount = bitCount;
            this.frequencies = frequencies;
        }
    }

    static class ArithFreqTable {
        int total;
        int[] low;
        int[] high;

        ArithFreqTable(int[] frequencies) {
            total = 0;
            for (int f : frequencies) total += f;

            low = new int[256];
            high = new int[256];

            int cum = 0;
            for (int i = 0; i < 256; i++) {
                low[i] = cum;
                cum += frequencies[i];
                high[i] = cum;
            }
        }
    }

    static class BitOutputStream {
        private int buffer = 0;
        private int bitPos = 0;
        private ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        private int bitsWritten = 0;

        void writeBit(int bit) {
            buffer = (buffer << 1) | (bit & 1);
            bitPos++;
            bitsWritten++;

            if (bitPos == 8) {
                bytes.write(buffer);
                buffer = 0;
                bitPos = 0;
            }
        }

        byte[] flush() {
            if (bitPos > 0) {
                buffer <<= (8 - bitPos);
                bytes.write(buffer);
            }
            return bytes.toByteArray();
        }

        int getBitsWritten() {
            return bitsWritten;
        }
    }

    public long sizeVal;
    private long resultVal;
    private byte[] testData;
    public ArithEncodedResult encoded;

    public ArithEncode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::ArithEncode";
    }

    private ArithEncodedResult arithEncode(byte[] data) {
        int[] frequencies = new int[256];
        for (byte b : data) {
            frequencies[b & 0xFF]++;
        }

        ArithFreqTable freqTable = new ArithFreqTable(frequencies);

        long low = 0;
        long high = 0xFFFFFFFFL;
        int pending = 0;
        BitOutputStream output = new BitOutputStream();

        for (byte b : data) {
            int idx = b & 0xFF;
            long range = high - low + 1;

            high = low + (range * freqTable.high[idx] / freqTable.total) - 1;
            low = low + (range * freqTable.low[idx] / freqTable.total);

            while (true) {
                if (high < 0x80000000L) {
                    output.writeBit(0);
                    for (int i = 0; i < pending; i++) output.writeBit(1);
                    pending = 0;
                } else if (low >= 0x80000000L) {
                    output.writeBit(1);
                    for (int i = 0; i < pending; i++) output.writeBit(0);
                    pending = 0;
                    low -= 0x80000000L;
                    high -= 0x80000000L;
                } else if (low >= 0x40000000L && high < 0xC0000000L) {
                    pending++;
                    low -= 0x40000000L;
                    high -= 0x40000000L;
                } else {
                    break;
                }

                low <<= 1;
                high = (high << 1) | 1;
                high &= 0xFFFFFFFFL;
            }
        }

        pending++;
        if (low < 0x40000000L) {
            output.writeBit(0);
            for (int i = 0; i < pending; i++) output.writeBit(1);
        } else {
            output.writeBit(1);
            for (int i = 0; i < pending; i++) output.writeBit(0);
        }

        return new ArithEncodedResult(output.flush(), output.getBitsWritten(), frequencies);
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);
    }

    @Override
    public void run(int iterationId) {
        encoded = arithEncode(testData);
        resultVal += encoded.data.length;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class ArithDecode extends Benchmark {
    static class BitInputStream {
        private byte[] bytes;
        private int bytePos = 0;
        private int bitPos = 0;
        private int currentByte = 0;

        BitInputStream(byte[] bytes) {
            this.bytes = bytes;
            if (bytes.length > 0) {
                currentByte = bytes[0] & 0xFF;
            }
        }

        int readBit() {
            if (bitPos == 8) {
                bytePos++;
                bitPos = 0;
                currentByte = bytePos < bytes.length ? (bytes[bytePos] & 0xFF) : 0;
            }

            int bit = (currentByte >> (7 - bitPos)) & 1;
            bitPos++;
            return bit;
        }
    }

    private long sizeVal;
    private long resultVal;
    private byte[] testData;
    private byte[] decoded;
    private ArithEncode.ArithEncodedResult encoded;

    public ArithDecode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::ArithDecode";
    }

    private byte[] arithDecode(ArithEncode.ArithEncodedResult encoded) {
        int[] frequencies = encoded.frequencies;
        int total = 0;
        for (int f : frequencies) total += f;
        int dataSize = total;

        int[] lowTable = new int[256];
        int[] highTable = new int[256];
        int cum = 0;
        for (int i = 0; i < 256; i++) {
            lowTable[i] = cum;
            cum += frequencies[i];
            highTable[i] = cum;
        }

        byte[] result = new byte[dataSize];
        BitInputStream input = new BitInputStream(encoded.data);

        long value = 0;
        for (int i = 0; i < 32; i++) {
            value = (value << 1) | input.readBit();
        }

        long low = 0;
        long high = 0xFFFFFFFFL;

        for (int j = 0; j < dataSize; j++) {
            long range = high - low + 1;
            long scaled = ((value - low + 1) * total - 1) / range;

            int symbol = 0;
            while (symbol < 255 && highTable[symbol] <= scaled) {
                symbol++;
            }

            result[j] = (byte) symbol;

            high = low + (range * highTable[symbol] / total) - 1;
            low = low + (range * lowTable[symbol] / total);

            while (true) {
                if (high >= 0x80000000L && low < 0x80000000L &&
                        (low < 0x40000000L || high >= 0xC0000000L)) {
                    break;
                }

                if (high < 0x80000000L) {

                } else if (low >= 0x80000000L) {
                    value -= 0x80000000L;
                    low -= 0x80000000L;
                    high -= 0x80000000L;
                } else if (low >= 0x40000000L && high < 0xC0000000L) {
                    value -= 0x40000000L;
                    low -= 0x40000000L;
                    high -= 0x40000000L;
                }

                low <<= 1;
                high = (high << 1) | 1;
                value = (value << 1) | input.readBit();
            }
        }

        return result;
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);

        ArithEncode encoder = new ArithEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    @Override
    public void run(int iterationId) {
        decoded = arithDecode(encoded);
        resultVal += decoded.length;
    }

    @Override
    public long checksum() {
        long res = resultVal;
        if (Arrays.equals(decoded, testData)) {
            res += 100000;
        }
        return res;
    }
}

class LZWEncode extends Benchmark {
    static class LZWResult {
        byte[] data;
        int dictSize;

        LZWResult(byte[] data, int dictSize) {
            this.data = data;
            this.dictSize = dictSize;
        }
    }

    public long sizeVal;
    private long resultVal;
    private byte[] testData;
    public LZWResult encoded;

    public LZWEncode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::LZWEncode";
    }

    private LZWResult lzwEncode(byte[] input) {
        if (input.length == 0) {
            return new LZWResult(new byte[0], 256);
        }

        Map<String, Integer> dict = new HashMap<>(4096);
        for (int i = 0; i < 256; i++) {
            dict.put(new String(new byte[] {(byte) i}, StandardCharsets.ISO_8859_1), i);
        }

        int nextCode = 256;
        ByteArrayOutputStream result = new ByteArrayOutputStream(input.length * 2);

        String current = new String(new byte[] {input[0]}, StandardCharsets.ISO_8859_1);

        for (int i = 1; i < input.length; i++) {
            String nextChar = new String(new byte[] {input[i]}, StandardCharsets.ISO_8859_1);
            String newStr = current + nextChar;

            if (dict.containsKey(newStr)) {
                current = newStr;
            } else {
                int code = dict.get(current);
                result.write((code >> 8) & 0xFF);
                result.write(code & 0xFF);

                dict.put(newStr, nextCode);
                nextCode++;
                current = nextChar;
            }
        }

        int code = dict.get(current);
        result.write((code >> 8) & 0xFF);
        result.write(code & 0xFF);

        return new LZWResult(result.toByteArray(), nextCode);
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);
    }

    @Override
    public void run(int iterationId) {
        encoded = lzwEncode(testData);
        resultVal += encoded.data.length;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}

class LZWDecode extends Benchmark {
    private long sizeVal;
    private long resultVal;
    private byte[] testData;
    private byte[] decoded;
    private LZWEncode.LZWResult encoded;

    public LZWDecode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Compress::LZWDecode";
    }

    private byte[] lzwDecode(LZWEncode.LZWResult encoded) {
        if (encoded.data.length == 0) {
            return new byte[0];
        }

        List<String> dict = new ArrayList<>(4096);
        for (int i = 0; i < 256; i++) {
            dict.add(new String(new byte[] {(byte) i}, StandardCharsets.ISO_8859_1));
        }

        ByteArrayOutputStream result = new ByteArrayOutputStream(encoded.data.length * 2);
        byte[] data = encoded.data;
        int pos = 0;

        int high = data[pos] & 0xFF;
        int low = data[pos + 1] & 0xFF;
        int oldCode = (high << 8) | low;
        pos += 2;

        String oldStr = dict.get(oldCode);
        try {
            result.write(oldStr.getBytes(StandardCharsets.ISO_8859_1));
        } catch (IOException e) {
            throw new RuntimeException("Unexpected IOException", e);
        }

        int nextCode = 256;

        while (pos < data.length) {
            high = data[pos] & 0xFF;
            low = data[pos + 1] & 0xFF;
            int newCode = (high << 8) | low;
            pos += 2;

            String newStr;

            if (newCode < dict.size()) {
                newStr = dict.get(newCode);
            } else if (newCode == nextCode) {
                newStr = oldStr + oldStr.substring(0, 1);
            } else {
                throw new RuntimeException("Error decode");
            }

            try {
                result.write(newStr.getBytes(StandardCharsets.ISO_8859_1));
            } catch (IOException e) {
                throw new RuntimeException("Unexpected IOException", e);
            }

            dict.add(oldStr + newStr.substring(0, 1));
            nextCode++;

            oldStr = newStr;
        }

        return result.toByteArray();
    }

    @Override
    public void prepare() {
        testData = Compress.generateTestData(sizeVal);

        LZWEncode encoder = new LZWEncode();
        encoder.sizeVal = sizeVal;
        encoder.prepare();
        encoder.run(0);
        encoded = encoder.encoded;
    }

    @Override
    public void run(int iterationId) {
        decoded = lzwDecode(encoded);
        resultVal += decoded.length;
    }

    @Override
    public long checksum() {
        long res = resultVal;
        if (Arrays.equals(decoded, testData)) {
            res += 100000;
        }
        return res;
    }
}