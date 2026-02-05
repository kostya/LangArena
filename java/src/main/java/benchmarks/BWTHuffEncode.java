package benchmarks;

import java.util.*;
import java.nio.ByteBuffer;

public class BWTHuffEncode extends Benchmark {

    public static class BWTResult {
        byte[] transformed;
        int originalIdx;

        BWTResult(byte[] transformed, int originalIdx) {
            this.transformed = transformed;
            this.originalIdx = originalIdx;
        }
    }

    public BWTResult bwtTransform(byte[] input) {
        int n = input.length;
        if (n == 0) {
            return new BWTResult(new byte[0], 0);
        }

        Integer[] sa = new Integer[n];
        for (int i = 0; i < n; i++) {
            sa[i] = i;
        }

        List<Integer>[] buckets = new List[256];
        for (int i = 0; i < 256; i++) {
            buckets[i] = new ArrayList<>();
        }

        for (int idx : sa) {
            int firstChar = input[idx] & 0xFF;
            buckets[firstChar].add(idx);
        }

        int pos = 0;
        for (int b = 0; b < 256; b++) {
            for (int idx : buckets[b]) {
                sa[pos++] = idx;
            }
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

                int[][] pairs = new int[n][2];
                for (int i = 0; i < n; i++) {
                    pairs[i][0] = rank[i];
                    pairs[i][1] = rank[(i + k) % n];
                }

                Arrays.sort(sa, new Comparator<Integer>() {
                    @Override
                    public int compare(Integer a, Integer b) {
                        int[] pairA = pairs[a];
                        int[] pairB = pairs[b];
                        if (pairA[0] != pairB[0]) {
                            return Integer.compare(pairA[0], pairB[0]);
                        }
                        return Integer.compare(pairA[1], pairB[1]);
                    }
                });

                int[] newRank = new int[n];
                newRank[sa[0]] = 0;
                for (int i = 1; i < n; i++) {
                    int[] prevPair = pairs[sa[i - 1]];
                    int[] currPair = pairs[sa[i]];
                    if (prevPair[0] != currPair[0] || prevPair[1] != currPair[1]) {
                        newRank[sa[i]] = newRank[sa[i - 1]] + 1;
                    } else {
                        newRank[sa[i]] = newRank[sa[i - 1]];
                    }
                }

                rank = newRank;
                k *= 2;
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

    public byte[] bwtInverse(BWTResult bwtResult) {
        byte[] bwt = bwtResult.transformed;
        int n = bwt.length;

        if (n == 0) {
            return new byte[0];
        }

        int[] counts = new int[256];
        for (byte b : bwt) {
            counts[b & 0xFF]++;
        }

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

    public static class HuffmanNode implements Comparable<HuffmanNode> {
        int frequency;
        Byte byteVal;
        HuffmanNode left;
        HuffmanNode right;

        HuffmanNode(int frequency, Byte byteVal) {
            this.frequency = frequency;
            this.byteVal = byteVal;
        }

        @Override
        public int compareTo(HuffmanNode other) {
            return Integer.compare(this.frequency, other.frequency);
        }

        boolean isLeaf() {
            return left == null && right == null;
        }
    }

    public HuffmanNode buildHuffmanTree(int[] frequencies) {
        PriorityQueue<HuffmanNode> heap = new PriorityQueue<>();

        for (int i = 0; i < frequencies.length; i++) {
            if (frequencies[i] > 0) {
                heap.offer(new HuffmanNode(frequencies[i], (byte) i));
            }
        }

        if (heap.size() == 1) {
            HuffmanNode node = heap.poll();
            HuffmanNode root = new HuffmanNode(node.frequency, null);
            root.left = node;
            root.right = new HuffmanNode(0, (byte) 0);
            return root;
        }

        while (heap.size() > 1) {
            HuffmanNode left = heap.poll();
            HuffmanNode right = heap.poll();

            HuffmanNode parent = new HuffmanNode(
                left.frequency + right.frequency,
                null
            );
            parent.left = left;
            parent.right = right;

            heap.offer(parent);
        }

        return heap.poll();
    }

    public void buildHuffmanCodes(HuffmanNode node, boolean[] prefix, int length,
                                  Map<Byte, boolean[]> codes) {
        if (node.byteVal != null) {
            if (length > 0 || node.byteVal != 0) {
                boolean[] code = Arrays.copyOf(prefix, length);
                codes.put(node.byteVal, code);
            }
        } else {
            if (node.left != null) {
                if (length >= prefix.length) {
                    prefix = Arrays.copyOf(prefix, prefix.length * 2);
                }
                prefix[length] = false;
                buildHuffmanCodes(node.left, prefix, length + 1, codes);
            }
            if (node.right != null) {
                if (length >= prefix.length) {
                    prefix = Arrays.copyOf(prefix, prefix.length * 2);
                }
                prefix[length] = true;
                buildHuffmanCodes(node.right, prefix, length + 1, codes);
            }
        }
    }

    public static class EncodedResult {
        byte[] data;
        int bitCount;

        EncodedResult(byte[] data, int bitCount) {
            this.data = data;
            this.bitCount = bitCount;
        }
    }

    public EncodedResult huffmanEncode(byte[] data, Map<Byte, boolean[]> codes) {

        byte[] result = new byte[data.length * 2]; 
        int currentByte = 0;
        int bitPos = 0;
        int byteIndex = 0;
        int totalBits = 0;

        for (byte b : data) {
            boolean[] code = codes.get(b);
            if (code == null) {
                throw new RuntimeException("Symbol " + b + " not found");
            }

            for (boolean bit : code) {
                if (bit) {
                    currentByte |= 1 << (7 - bitPos);
                }
                bitPos++;
                totalBits++;

                if (bitPos == 8) {
                    result[byteIndex++] = (byte) currentByte;
                    currentByte = 0;
                    bitPos = 0;
                }
            }
        }

        if (bitPos > 0) {
            result[byteIndex++] = (byte) currentByte;
        }

        byte[] finalResult = new byte[byteIndex];
        System.arraycopy(result, 0, finalResult, 0, byteIndex);
        return new EncodedResult(finalResult, totalBits);
    }

    public byte[] huffmanDecode(byte[] encoded, HuffmanNode root, int bitCount) {
        byte[] result = new byte[bitCount / 4 + 1];
        int resultIdx = 0;
        HuffmanNode currentNode = root;
        int bitsProcessed = 0;

        outer: for (byte byteVal : encoded) {
            for (int bitPos = 0; bitPos < 8; bitPos++) {
                if (bitsProcessed >= bitCount) {
                    break outer;
                }

                boolean bit = ((byteVal >> (7 - bitPos)) & 1) == 1;
                bitsProcessed++;

                currentNode = bit ? currentNode.right : currentNode.left;

                if (currentNode.isLeaf()) {
                    if (currentNode.byteVal != 0) {
                        if (resultIdx >= result.length) {
                            byte[] newArray = new byte[result.length * 2];
                            System.arraycopy(result, 0, newArray, 0, result.length);
                            result = newArray;
                        }
                        result[resultIdx++] = currentNode.byteVal;
                    }
                    currentNode = root;
                }
            }
        }

        byte[] finalResult = new byte[resultIdx];
        System.arraycopy(result, 0, finalResult, 0, resultIdx);
        return finalResult;
    }

    public static class CompressedData {
        BWTResult bwtResult;
        int[] frequencies;
        byte[] encodedBits;
        int originalBitCount;

        CompressedData(BWTResult bwtResult, int[] frequencies, 
                      byte[] encodedBits, int originalBitCount) {
            this.bwtResult = bwtResult;
            this.frequencies = frequencies;
            this.encodedBits = encodedBits;
            this.originalBitCount = originalBitCount;
        }
    }

    public CompressedData compress(byte[] data) {

        BWTResult bwtResult = bwtTransform(data);

        int[] frequencies = new int[256];
        for (byte b : bwtResult.transformed) {
            frequencies[b & 0xFF]++;
        }

        HuffmanNode huffmanTree = buildHuffmanTree(frequencies);

        Map<Byte, boolean[]> huffmanCodes = new HashMap<>();
        buildHuffmanCodes(huffmanTree, new boolean[32], 0, huffmanCodes);

        EncodedResult encoded = huffmanEncode(bwtResult.transformed, huffmanCodes);

        return new CompressedData(bwtResult, frequencies, 
                                 encoded.data, encoded.bitCount);
    }

    public byte[] decompress(CompressedData compressed) {

        HuffmanNode huffmanTree = buildHuffmanTree(compressed.frequencies);

        byte[] decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        );

        BWTResult bwtResult = new BWTResult(decoded, compressed.bwtResult.originalIdx);

        return bwtInverse(bwtResult);
    }

    public long sizeVal;
    public byte[] testData;
    public long resultVal;

    public BWTHuffEncode() {
        sizeVal = configVal("size");
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "BWTHuffEncode";
    }

    public byte[] generateTestData(long dataSize) {
        String pattern = "ABRACADABRA";
        byte[] data = new byte[(int) dataSize];

        for (int i = 0; i < data.length; i++) {
            data[i] = (byte) pattern.charAt(i % pattern.length());
        }

        return data;
    }

    @Override
    public void prepare() {
        testData = generateTestData(sizeVal);
    }

    @Override
    public void run(int iterationId) {
        CompressedData compressed = compress(testData);
        resultVal += compressed.encodedBits.length;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}