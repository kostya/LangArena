using System;
using System.Collections.Generic;
using System.Linq;

public class Compression : Benchmark
{
    // ==================== BWT ====================
    private class BWTResult
    {
        public byte[] Transformed { get; }
        public int OriginalIdx { get; }
        
        public BWTResult(byte[] transformed, int originalIdx)
        {
            Transformed = transformed;
            OriginalIdx = originalIdx;
        }
    }
    
    private BWTResult BwtTransform(byte[] input)
    {
        int n = input.Length;
        if (n == 0)
        {
            return new BWTResult(Array.Empty<byte>(), 0);
        }
        
        // 1. Создаём удвоенную строку
        byte[] doubled = new byte[n * 2];
        Array.Copy(input, 0, doubled, 0, n);
        Array.Copy(input, 0, doubled, n, n);
        
        // 2. Создаём и сортируем суффиксный массив
        int[] sa = Enumerable.Range(0, n).ToArray();
        
        // 3. Фаза 0: сортировка по первому символу (Radix sort)
        List<int>[] buckets = new List<int>[256];
        for (int i = 0; i < 256; i++)
        {
            buckets[i] = new List<int>();
        }
        
        foreach (int idx in sa)
        {
            byte firstChar = input[idx];
            buckets[firstChar].Add(idx);
        }
        
        int pos = 0;
        for (int b = 0; b < 256; b++)
        {
            foreach (int idx in buckets[b])
            {
                sa[pos++] = idx;
            }
        }
        
        // 4. Фаза 1: сортировка по парам символов
        if (n > 1)
        {
            // Присваиваем ранги по первому символу
            int[] rank = new int[n];
            int currentRank = 0;
            byte prevChar = input[sa[0]];
            
            for (int i = 0; i < n; i++)
            {
                int idx = sa[i];
                byte currChar = input[idx];
                if (currChar != prevChar)
                {
                    currentRank++;
                    prevChar = currChar;
                }
                rank[idx] = currentRank;
            }
            
            // Сортируем по парам (ранг[i], ранг[i+1])
            int k = 1;
            while (k < n)
            {
                // Создаём пары
                (int, int)[] pairs = new (int, int)[n];
                for (int i = 0; i < n; i++)
                {
                    pairs[i] = (rank[i], rank[(i + k) % n]);
                }
                
                // Сортируем индексы по парам
                Array.Sort(sa, (a, b) =>
                {
                    var pairA = pairs[a];
                    var pairB = pairs[b];
                    if (pairA.Item1 != pairB.Item1)
                    {
                        return pairA.Item1.CompareTo(pairB.Item1);
                    }
                    return pairA.Item2.CompareTo(pairB.Item2);
                });
                
                // Обновляем ранги
                int[] newRank = new int[n];
                newRank[sa[0]] = 0;
                for (int i = 1; i < n; i++)
                {
                    var prevPair = pairs[sa[i - 1]];
                    var currPair = pairs[sa[i]];
                    newRank[sa[i]] = newRank[sa[i - 1]] + 
                        (prevPair != currPair ? 1 : 0);
                }
                
                Array.Copy(newRank, rank, n);
                k *= 2;
            }
        }
        
        // 5. Собираем BWT результат
        byte[] transformed = new byte[n];
        int originalIdx = 0;
        
        for (int i = 0; i < n; i++)
        {
            int suffix = sa[i];
            if (suffix == 0)
            {
                transformed[i] = input[n - 1];
                originalIdx = i;
            }
            else
            {
                transformed[i] = input[suffix - 1];
            }
        }
        
        return new BWTResult(transformed, originalIdx);
    }
    
    private byte[] BwtInverse(BWTResult bwtResult)
    {
        byte[] bwt = bwtResult.Transformed;
        int n = bwt.Length;
        if (n == 0)
        {
            return Array.Empty<byte>();
        }
        
        // 1. Подсчитываем частоты символов
        int[] counts = new int[256];
        foreach (byte b in bwt)
        {
            counts[b]++;
        }
        
        // 2. Вычисляем стартовые позиции для каждого символа
        int[] positions = new int[256];
        int total = 0;
        for (int i = 0; i < 256; i++)
        {
            positions[i] = total;
            total += counts[i];
        }
        
        // 3. Строим массив next (LF-маппинг)
        int[] next = new int[n];
        int[] tempCounts = new int[256];
        
        for (int i = 0; i < n; i++)
        {
            int byteIdx = bwt[i];
            int pos = positions[byteIdx] + tempCounts[byteIdx];
            next[pos] = i;
            tempCounts[byteIdx]++;
        }
        
        // 4. Восстанавливаем исходную строку
        byte[] result = new byte[n];
        int idx = bwtResult.OriginalIdx;
        
        for (int i = 0; i < n; i++)
        {
            idx = next[idx];
            result[i] = bwt[idx];
        }
        
        return result;
    }
    
    // ==================== Huffman ====================
    private class HuffmanNode : IComparable<HuffmanNode>
    {
        public int Frequency { get; }
        public byte? ByteVal { get; }
        public bool IsLeaf { get; }
        public HuffmanNode? Left { get; }
        public HuffmanNode? Right { get; }
        
        public HuffmanNode(int frequency, byte? byteVal = null, bool isLeaf = true, 
                          HuffmanNode? left = null, HuffmanNode? right = null)
        {
            Frequency = frequency;
            ByteVal = byteVal;
            IsLeaf = isLeaf;
            Left = left;
            Right = right;
        }
        
        public int CompareTo(HuffmanNode? other)
        {
            return Frequency.CompareTo(other?.Frequency);
        }
    }
    
    private HuffmanNode BuildHuffmanTree(int[] frequencies)
    {
        var heap = new PriorityQueue<HuffmanNode, int>();
        
        // Добавляем все символы с ненулевой частотой
        for (int i = 0; i < frequencies.Length; i++)
        {
            if (frequencies[i] > 0)
            {
                heap.Enqueue(new HuffmanNode(frequencies[i], (byte)i), frequencies[i]);
            }
        }
        
        // Если только один символ, создаём искусственный узел
        if (heap.Count == 1)
        {
            var node = heap.Dequeue();
            return new HuffmanNode(
                frequency: node.Frequency,
                byteVal: null,
                isLeaf: false,
                left: node,
                right: new HuffmanNode(0, 0)
            );
        }
        
        // Строим дерево
        while (heap.Count > 1)
        {
            var left = heap.Dequeue();
            var right = heap.Dequeue();
            
            var parent = new HuffmanNode(
                frequency: left.Frequency + right.Frequency,
                byteVal: null,
                isLeaf: false,
                left: left,
                right: right
            );
            
            heap.Enqueue(parent, parent.Frequency);
        }
        
        return heap.Dequeue();
    }
    
    private class HuffmanCodes
    {
        public int[] CodeLengths { get; } = new int[256];
        public int[] Codes { get; } = new int[256];
    }
    
    private void BuildHuffmanCodes(HuffmanNode node, int code = 0, int length = 0, HuffmanCodes? huffmanCodes = null)
    {
        huffmanCodes ??= new HuffmanCodes();
        
        if (node.IsLeaf)
        {
            if (length > 0 || node.ByteVal != 0)
            {
                int idx = node.ByteVal!.Value;
                huffmanCodes.CodeLengths[idx] = length;
                huffmanCodes.Codes[idx] = code;
            }
        }
        else
        {
            if (node.Left != null)
            {
                BuildHuffmanCodes(node.Left, code << 1, length + 1, huffmanCodes);
            }
            if (node.Right != null)
            {
                BuildHuffmanCodes(node.Right, (code << 1) | 1, length + 1, huffmanCodes);
            }
        }
    }
    
    private class EncodedResult
    {
        public byte[] Data { get; }
        public int BitCount { get; }
        
        public EncodedResult(byte[] data, int bitCount)
        {
            Data = data;
            BitCount = bitCount;
        }
    }
    
    private EncodedResult HuffmanEncode(byte[] data, HuffmanCodes huffmanCodes)
    {
        // Предварительное выделение с запасом
        byte[] result = new byte[data.Length * 2];
        byte currentByte = 0;
        int bitPos = 0;
        int byteIndex = 0;
        int totalBits = 0;
        
        foreach (byte b in data)
        {
            int idx = b;
            int code = huffmanCodes.Codes[idx];
            int length = huffmanCodes.CodeLengths[idx];
            
            // Копируем биты из code
            for (int i = length - 1; i >= 0; i--)
            {
                if ((code & (1 << i)) != 0)
                {
                    currentByte |= (byte)(1 << (7 - bitPos));
                }
                bitPos++;
                totalBits++;
                
                if (bitPos == 8)
                {
                    result[byteIndex++] = currentByte;
                    currentByte = 0;
                    bitPos = 0;
                }
            }
        }
        
        // Последний неполный байт
        if (bitPos > 0)
        {
            result[byteIndex++] = currentByte;
        }
        
        return new EncodedResult(result[0..byteIndex], totalBits);
    }
    
    private byte[] HuffmanDecode(byte[] encoded, HuffmanNode root, int bitCount)
    {
        var result = new List<byte>(bitCount / 4 + 1);
        HuffmanNode currentNode = root;
        int bitsProcessed = 0;
        int byteIndex = 0;
        
        while (bitsProcessed < bitCount && byteIndex < encoded.Length)
        {
            byte byteVal = encoded[byteIndex++];
            
            for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--)
            {
                bool bit = ((byteVal >> bitPos) & 1) == 1;
                bitsProcessed++;
                
                currentNode = bit ? currentNode.Right! : currentNode.Left!;
                
                if (currentNode.IsLeaf)
                {
                    if (currentNode.ByteVal != 0)
                    {
                        result.Add(currentNode.ByteVal!.Value);
                    }
                    currentNode = root;
                }
            }
        }
        
        return result.ToArray();
    }
    
    // ==================== Компрессор ====================
    private class CompressedData
    {
        public BWTResult BwtResult { get; }
        public int[] Frequencies { get; }
        public byte[] EncodedBits { get; }
        public int OriginalBitCount { get; }
        
        public CompressedData(BWTResult bwtResult, int[] frequencies, byte[] encodedBits, int originalBitCount)
        {
            BwtResult = bwtResult;
            Frequencies = frequencies;
            EncodedBits = encodedBits;
            OriginalBitCount = originalBitCount;
        }
    }
    
    private CompressedData Compress(byte[] data)
    {
        // 1. BWT преобразование
        BWTResult bwtResult = BwtTransform(data);
        
        // 2. Подсчёт частот
        int[] frequencies = new int[256];
        foreach (byte b in bwtResult.Transformed)
        {
            frequencies[b]++;
        }
        
        // 3. Построение дерева Huffman
        HuffmanNode huffmanTree = BuildHuffmanTree(frequencies);
        
        // 4. Построение кодов
        HuffmanCodes huffmanCodes = new HuffmanCodes();
        BuildHuffmanCodes(huffmanTree, huffmanCodes: huffmanCodes);
        
        // 5. Кодирование
        EncodedResult encoded = HuffmanEncode(bwtResult.Transformed, huffmanCodes);
        
        return new CompressedData(
            bwtResult,
            frequencies,
            encoded.Data,
            encoded.BitCount
        );
    }
    
    private byte[] Decompress(CompressedData compressed)
    {
        // 1. Восстанавливаем дерево Huffman
        HuffmanNode huffmanTree = BuildHuffmanTree(compressed.Frequencies);
        
        // 2. Декодирование Huffman
        byte[] decoded = HuffmanDecode(
            compressed.EncodedBits,
            huffmanTree,
            compressed.OriginalBitCount
        );
        
        // 3. Обратное BWT
        BWTResult bwtResult = new BWTResult(
            decoded,
            compressed.BwtResult.OriginalIdx
        );
        
        return BwtInverse(bwtResult);
    }
    
    // ==================== Бенчмарк ====================
    private int _iterations;
    private byte[] _testData = Array.Empty<byte>();
    private long _result;
    
    public Compression()
    {
        var className = nameof(Compression);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            _iterations = int.TryParse(value, out var iter) ? iter : 0;
        }
        else
        {
            _iterations = 0;
        }
    }
    
    private byte[] GenerateTestData(int size)
    {
        byte[] pattern = "ABRACADABRA"u8.ToArray();
        byte[] data = new byte[size];
        
        for (int i = 0; i < size; i++)
        {
            data[i] = pattern[i % pattern.Length];
        }
        
        return data;
    }
    
    public override void Prepare()
    {
        _testData = GenerateTestData(_iterations);
    }
    
    public override void Run()
    {
        uint totalChecksum = 0;
        
        for (int i = 0; i < 5; i++)
        {
            // Компрессия
            CompressedData compressed = Compress(_testData);
            
            // Декомпрессия
            byte[] decompressed = Decompress(compressed);
            
            // Подсчёт checksum
            uint checksum = Helper.Checksum(decompressed);
            
            totalChecksum = (totalChecksum + (uint)compressed.EncodedBits.Length) & 0xFFFFFFFFu;
            totalChecksum = (totalChecksum + checksum) & 0xFFFFFFFFu;
        }
        
        _result = totalChecksum;
    }
    
    public override long Result => _result;
}