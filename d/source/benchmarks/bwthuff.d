module benchmarks.bwthuff;

import benchmark;
import helper;
import std.stdio;
import std.algorithm;
import std.conv;
import std.array;
import std.range;
import std.typecons;

class BWTHuffEncode : Benchmark {
private:
    struct BWTResult {
        ubyte[] transformed;
        size_t originalIdx;

        this(ubyte[] t, size_t idx) {
            transformed = t;
            originalIdx = idx;
        }
    }

    class HuffmanNode {
        int frequency;
        ubyte byteVal;
        bool isLeaf;
        HuffmanNode left;
        HuffmanNode right;

        this(int freq, ubyte val = 0, bool leaf = true) {
            frequency = freq;
            byteVal = val;
            isLeaf = leaf;
        }
    }

    class SimpleHeap {
    private:
        HuffmanNode[] heap;

        void siftUp(size_t idx) {
            while (idx > 0) {
                size_t parent = (idx - 1) / 2;
                if (heap[parent].frequency <= heap[idx].frequency) break;

                swap(heap[parent], heap[idx]);
                idx = parent;
            }
        }

        void siftDown(size_t idx) {
            size_t n = heap.length;
            while (true) {
                size_t smallest = idx;
                size_t left = idx * 2 + 1;
                size_t right = left + 1;

                if (left < n && heap[left].frequency < heap[smallest].frequency) {
                    smallest = left;
                }
                if (right < n && heap[right].frequency < heap[smallest].frequency) {
                    smallest = right;
                }
                if (smallest == idx) break;

                swap(heap[idx], heap[smallest]);
                idx = smallest;
            }
        }

    public:
        void insert(HuffmanNode node) {
            heap ~= node;
            siftUp(heap.length - 1);
        }

        HuffmanNode extractMin() {
            if (heap.empty) return null;
            HuffmanNode minNode = heap[0];
            heap[0] = heap[$ - 1];
            heap.length = heap.length - 1;
            if (!heap.empty) siftDown(0);
            return minNode;
        }

        bool empty() const { return heap.empty; }
        size_t length() const { return heap.length; }

        inout(HuffmanNode) front() inout { 
            return heap.length > 0 ? heap[0] : null; 
        }

        void removeFront() {
            if (!heap.empty) extractMin();
        }
    }

    BWTResult bwtTransform(const ubyte[] input) {
        size_t n = input.length;
        if (n == 0) return BWTResult([], 0);

        size_t[] sa = new size_t[n];
        foreach (i; 0..n) sa[i] = i;

        size_t[256] bucketSizes = 0;
        size_t[256] bucketStarts;

        foreach (idx; sa) {
            bucketSizes[input[idx]]++;
        }

        size_t total = 0;
        foreach (i; 0..256) {
            bucketStarts[i] = total;
            total += bucketSizes[i];
            bucketSizes[i] = 0; 
        }

        size_t[] tempSA = new size_t[n];
        foreach (idx; sa) {
            ubyte c = input[idx];
            size_t pos = bucketStarts[c] + bucketSizes[c];
            tempSA[pos] = idx;
            bucketSizes[c]++;
        }
        sa = tempSA;

        if (n > 1) {
            int[] rank = new int[n];
            int currentRank = 0;
            ubyte prevChar = input[sa[0]];

            foreach (i; 0..n) {
                size_t idx = sa[i];
                ubyte currChar = input[idx];
                if (currChar != prevChar) {
                    currentRank++;
                    prevChar = currChar;
                }
                rank[idx] = currentRank;
            }

            size_t k = 1;
            while (k < n) {

                static struct Pair {
                    int first, second;

                    int opCmp(ref const Pair other) const {
                        if (first != other.first) return first - other.first;
                        return second - other.second;
                    }
                }

                Pair[] pairs = new Pair[n];
                foreach (i; 0..n) {
                    pairs[i] = Pair(rank[i], rank[(i + k) % n]);
                }

                sort!((a, b) => pairs[a].opCmp(pairs[b]) < 0)(sa);

                int[] newRank = new int[n];
                newRank[sa[0]] = 0;
                foreach (i; 1..n) {
                    const prevPair = pairs[sa[i - 1]];
                    const currPair = pairs[sa[i]];
                    newRank[sa[i]] = newRank[sa[i - 1]] + 
                        ((prevPair.first != currPair.first || 
                          prevPair.second != currPair.second) ? 1 : 0);
                }

                rank = newRank;
                k *= 2;
            }
        }

        ubyte[] transformed = new ubyte[n];
        size_t originalIdx = 0;

        foreach (i; 0..n) {
            size_t suffix = sa[i];
            if (suffix == 0) {
                transformed[i] = input[n - 1];
                originalIdx = i;
            } else {
                transformed[i] = input[suffix - 1];
            }
        }

        return BWTResult(transformed, originalIdx);
    }

    ubyte[] bwtInverse(BWTResult bwtResult) {
        const ubyte[] bwt = bwtResult.transformed;
        const n = bwt.length;
        if (n == 0) return [];

        size_t[256] counts = 0;
        size_t[256] positions = 0;

        foreach (b; bwt) {
            counts[b]++;
        }

        size_t total = 0;
        foreach (i; 0..256) {
            positions[i] = total;
            total += counts[i];
        }

        size_t[] next = new size_t[n];
        size_t[256] tempCounts = 0;

        foreach (i; 0..n) {
            ubyte b = bwt[i];
            size_t pos = positions[b] + tempCounts[b];
            next[pos] = i;
            tempCounts[b]++;
        }

        ubyte[] result = new ubyte[n];
        size_t idx = bwtResult.originalIdx;

        foreach (i; 0..n) {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

    HuffmanNode buildHuffmanTree(int[256] frequencies) {
        auto heap = new SimpleHeap();

        foreach (i; 0..256) {
            if (frequencies[i] > 0) {
                heap.insert(new HuffmanNode(frequencies[i], cast(ubyte)i));
            }
        }

        if (heap.length == 1) {
            auto node = heap.front();
            heap.removeFront();

            auto root = new HuffmanNode(node.frequency, 0, false);
            root.left = node;
            root.right = new HuffmanNode(0, 0, true);
            return root;
        }

        while (heap.length > 1) {
            auto left = heap.front();
            heap.removeFront();
            auto right = heap.front();
            heap.removeFront();

            auto parent = new HuffmanNode(
                left.frequency + right.frequency, 0, false);
            parent.left = left;
            parent.right = right;

            heap.insert(parent);
        }

        return heap.front();
    }

    struct HuffmanCodes {
        int[256] codeLengths;
        int[256] codes;
    }

    void buildHuffmanCodes(HuffmanNode node, int code, int length, 
                          ref HuffmanCodes huffmanCodes) {
        if (node.isLeaf) {
            if (length > 0) {
                int idx = node.byteVal;
                huffmanCodes.codeLengths[idx] = length;
                huffmanCodes.codes[idx] = code;
            }
        } else {
            if (node.left !is null) {
                buildHuffmanCodes(node.left, code << 1, length + 1, huffmanCodes);
            }
            if (node.right !is null) {
                buildHuffmanCodes(node.right, (code << 1) | 1, length + 1, huffmanCodes);
            }
        }
    }

    struct EncodedResult {
        ubyte[] data;
        int bitCount;
    }

    EncodedResult huffmanEncode(const ubyte[] data, HuffmanCodes huffmanCodes) {
        ubyte[] result = new ubyte[data.length * 2];
        ubyte currentByte = 0;
        int bitPos = 0;
        size_t byteIndex = 0;
        int totalBits = 0;

        foreach (b; data) {
            int idx = b;
            int code = huffmanCodes.codes[idx];
            int length = huffmanCodes.codeLengths[idx];

            for (int i = length - 1; i >= 0; i--) {
                if ((code & (1 << i)) != 0) {
                    currentByte |= 1 << (7 - bitPos);
                }
                bitPos++;
                totalBits++;

                if (bitPos == 8) {
                    result[byteIndex++] = currentByte;
                    currentByte = 0;
                    bitPos = 0;
                }
            }
        }

        if (bitPos > 0) {
            result[byteIndex++] = currentByte;
        }

        result.length = byteIndex;
        return EncodedResult(result, totalBits);
    }

    ubyte[] huffmanDecode(const ubyte[] encoded, HuffmanNode root, int bitCount) {
        ubyte[] result;
        result.reserve(bitCount / 4 + 1);

        auto currentNode = root;
        int bitsProcessed = 0;
        size_t byteIndex = 0;

        while (bitsProcessed < bitCount && byteIndex < encoded.length) {
            ubyte byteVal = encoded[byteIndex++];

            if (bitsProcessed + 8 <= bitCount) {
                for (int bitPos = 7; bitPos >= 0; bitPos--) {
                    bool bit = ((byteVal >> bitPos) & 1) == 1;

                    if (bit) {
                        if (currentNode.right is null) return result;
                        currentNode = currentNode.right;
                    } else {
                        if (currentNode.left is null) return result;
                        currentNode = currentNode.left;
                    }

                    if (currentNode.isLeaf) {
                        result ~= currentNode.byteVal;
                        currentNode = root;
                    }
                }
                bitsProcessed += 8;
            } else {
                for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--) {
                    bool bit = ((byteVal >> bitPos) & 1) == 1;

                    if (bit) {
                        if (currentNode.right is null) return result;
                        currentNode = currentNode.right;
                    } else {
                        if (currentNode.left is null) return result;
                        currentNode = currentNode.left;
                    }

                    bitsProcessed++;

                    if (currentNode.isLeaf) {
                        result ~= currentNode.byteVal;
                        currentNode = root;
                    }
                }
            }
        }

        return result;
    }

public:
    struct CompressedData {
        BWTResult bwtResult;
        int[256] frequencies;
        ubyte[] encodedBits;
        int originalBitCount;
    }

    CompressedData compress(const ubyte[] data) {
        BWTResult bwtResult = bwtTransform(data);

        int[256] frequencies = 0;
        foreach (b; bwtResult.transformed) {
            frequencies[b]++;
        }

        HuffmanNode huffmanTree = buildHuffmanTree(frequencies);

        HuffmanCodes huffmanCodes;
        huffmanCodes.codeLengths[] = 0;
        huffmanCodes.codes[] = 0;
        buildHuffmanCodes(huffmanTree, 0, 0, huffmanCodes);

        EncodedResult encoded = huffmanEncode(bwtResult.transformed, huffmanCodes);

        return CompressedData(
            bwtResult,
            frequencies,
            encoded.data,
            encoded.bitCount
        );
    }

    ubyte[] decompress(CompressedData compressed) {
        HuffmanNode huffmanTree = buildHuffmanTree(compressed.frequencies);

        ubyte[] decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        );

        BWTResult bwtResult = BWTResult(decoded, compressed.bwtResult.originalIdx);
        return bwtInverse(bwtResult);
    }

    ubyte[] generateTestData(long dataSize) {
        string pattern = "ABRACADABRA";
        ubyte[] data = new ubyte[cast(size_t)dataSize];

        foreach (i; 0..dataSize) {
            data[cast(size_t)i] = cast(ubyte)pattern[i % pattern.length];
        }

        return data;
    }

public:
    long sizeVal;
    ubyte[] testData;
    uint resultVal;

    this() {
        resultVal = 0;
        sizeVal = configVal("size");
    }

    override string className() const { return "BWTHuffEncode"; }    

    override void prepare() {
        testData = generateTestData(sizeVal);
    }

    override void run(int iterationId) {
        CompressedData compressed = compress(testData);
        resultVal += cast(uint)compressed.encodedBits.length;
    }

    override uint checksum() {
        return resultVal;
    }
}

class BWTHuffDecode : BWTHuffEncode {
private:
    CompressedData compressedData;
    ubyte[] decompressed;

public:
    this() {
        sizeVal = configVal("size");
    }

    override string className() const { return "BWTHuffDecode"; }    

    override void prepare() {
        testData = generateTestData(sizeVal);
        compressedData = compress(testData);
    }

    override void run(int iterationId) {
        decompressed = decompress(compressedData);
        resultVal += cast(uint)decompressed.length;
    }

    override uint checksum() {
        uint res = resultVal;
        if (testData == decompressed) {
            res += 1000000;
        }
        return res;
    }
}