package benchmarks;

import java.util.*;
import java.nio.ByteBuffer;

public class Compression extends Benchmark {
    private int iterations;
    private byte[] testData;
    private long result;
    
    // ==================== BWT ====================
    private static class BWTResult {
        byte[] transformed;
        int originalIdx;
        
        BWTResult(byte[] transformed, int originalIdx) {
            this.transformed = transformed;
            this.originalIdx = originalIdx;
        }
    }
    
    private BWTResult bwtTransform(byte[] input) {
        int n = input.length;
        if (n == 0) {
            return new BWTResult(new byte[0], 0);
        }

        // 1. Создаём суффиксный массив
        Integer[] sa = new Integer[n];
        for (int i = 0; i < n; i++) {
            sa[i] = i;
        }

        // 2. Фаза 0: сортировка по первому символу (Radix sort)
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

        // 3. Фаза 1: сортировка по парам символов
        if (n > 1) {
            // Присваиваем ранги по первому символу
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

            // Сортируем по парам (ранг[i], ранг[i+1])
            int k = 1;
            while (k < n) {
                // Создаём пары
                int[][] pairs = new int[n][2];
                for (int i = 0; i < n; i++) {
                    pairs[i][0] = rank[i];
                    pairs[i][1] = rank[(i + k) % n];
                }

                // Сортируем индексы по парам
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

                // Обновляем ранги
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

        // 4. Собираем BWT результат
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
    // Быстрое обратное BWT как в Rust
    private byte[] bwtInverse(BWTResult bwtResult) {
        byte[] bwt = bwtResult.transformed;
        int n = bwt.length;
        
        if (n == 0) {
            return new byte[0];
        }
        
        // Оптимизация: используем примитивные массивы как в Rust
        // 1. Подсчитываем частоты символов
        int[] counts = new int[256];
        for (byte b : bwt) {
            counts[b & 0xFF]++;
        }
        
        // 2. Вычисляем стартовые позиции
        int[] positions = new int[256];
        int total = 0;
        for (int i = 0; i < 256; i++) {
            positions[i] = total;
            total += counts[i];
        }
        
        // 3. Строим массив next (LF-маппинг)
        int[] next = new int[n];
        int[] tempCounts = new int[256];
        
        for (int i = 0; i < n; i++) {
            int byteIdx = bwt[i] & 0xFF;
            int pos = positions[byteIdx] + tempCounts[byteIdx];
            next[pos] = i;
            tempCounts[byteIdx]++;
        }
        
        // 4. Восстанавливаем строку
        byte[] result = new byte[n];
        int idx = bwtResult.originalIdx;
        
        for (int i = 0; i < n; i++) {
            idx = next[idx];
            result[i] = bwt[idx];
        }
        
        return result;
    }
    
    // ==================== Huffman ====================
    private static class HuffmanNode implements Comparable<HuffmanNode> {
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
    
    private HuffmanNode buildHuffmanTree(int[] frequencies) {
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
    
    // Оптимизация: используем boolean[] вместо String
    private void buildHuffmanCodes(HuffmanNode node, boolean[] prefix, int length,
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
    
    private static class EncodedResult {
        byte[] data;
        int bitCount;
        
        EncodedResult(byte[] data, int bitCount) {
            this.data = data;
            this.bitCount = bitCount;
        }
    }
    
    // Быстрое кодирование как в Rust
    private EncodedResult huffmanEncode(byte[] data, Map<Byte, boolean[]> codes) {
        // Предварительное выделение
        byte[] result = new byte[data.length * 2]; // Максимальный размер
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
    
    private byte[] huffmanDecode(byte[] encoded, HuffmanNode root, int bitCount) {
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
    
    // ==================== Компрессор ====================
    private static class CompressedData {
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
    
    private CompressedData compress(byte[] data) {
        // 1. BWT преобразование
        BWTResult bwtResult = bwtTransform(data);
        
        // 2. Подсчёт частот
        int[] frequencies = new int[256];
        for (byte b : bwtResult.transformed) {
            frequencies[b & 0xFF]++;
        }
        
        // 3. Построение дерева
        HuffmanNode huffmanTree = buildHuffmanTree(frequencies);
        
        // 4. Построение кодов (используем boolean[])
        Map<Byte, boolean[]> huffmanCodes = new HashMap<>();
        buildHuffmanCodes(huffmanTree, new boolean[32], 0, huffmanCodes);
        
        // 5. Кодирование
        EncodedResult encoded = huffmanEncode(bwtResult.transformed, huffmanCodes);
        
        return new CompressedData(bwtResult, frequencies, 
                                 encoded.data, encoded.bitCount);
    }
    
    private byte[] decompress(CompressedData compressed) {
        // 1. Восстанавливаем дерево
        HuffmanNode huffmanTree = buildHuffmanTree(compressed.frequencies);
        
        // 2. Декодирование
        byte[] decoded = huffmanDecode(
            compressed.encodedBits,
            huffmanTree,
            compressed.originalBitCount
        );
        
        // 3. Обратное BWT
        BWTResult bwtResult = new BWTResult(decoded, compressed.bwtResult.originalIdx);
        
        return bwtInverse(bwtResult);
    }
    
    // ==================== Benchmark ====================
    public Compression() {
        this.iterations = getIterations();
        this.result = 0;
    }
    
    private byte[] generateTestData(int size) {
        byte[] pattern = "ABRACADABRA".getBytes();
        byte[] data = new byte[size];
        
        for (int i = 0; i < size; i++) {
            data[i] = pattern[i % pattern.length];
        }
        
        return data;
    }
    
    @Override
    public void prepare() {
        testData = generateTestData(iterations);
    }
    
    @Override
    public void run() {
        long totalChecksum = 0;
        
        for (int i = 0; i < 5; i++) {
            CompressedData compressed = compress(testData);
            byte[] decompressed = decompress(compressed);
            long checksum = Helper.checksum(decompressed);
            
            totalChecksum = (totalChecksum + compressed.encodedBits.length) & 0xFFFFFFFFL;
            totalChecksum = (totalChecksum + (int)checksum) & 0xFFFFFFFFL;
        }
        
        result = totalChecksum;
    }
    
    @Override
    public long getResult() {
        return result;
    }
}