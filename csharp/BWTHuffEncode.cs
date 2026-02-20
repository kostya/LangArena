using System;
using System.Collections.Generic;
using System.Linq;

public class BWTHuffEncode : Benchmark
{
    public class BWTResult
    {
        public byte[] Transformed { get; }
        public int OriginalIdx { get; }

        public BWTResult(byte[] transformed, int originalIdx)
        {
            Transformed = transformed;
            OriginalIdx = originalIdx;
        }
    }

    public BWTResult BwtTransform(byte[] input)
    {
        int n = input.Length;
        if (n == 0) return new BWTResult(Array.Empty<byte>(), 0);

        byte[] doubled = new byte[n * 2];
        Array.Copy(input, 0, doubled, 0, n);
        Array.Copy(input, 0, doubled, n, n);

        int[] sa = Enumerable.Range(0, n).ToArray();

        List<int>[] buckets = new List<int>[256];
        for (int i = 0; i < 256; i++) buckets[i] = new List<int>();

        foreach (int idx in sa) buckets[input[idx]].Add(idx);

        int pos = 0;
        for (int b = 0; b < 256; b++)
        {
            foreach (int idx in buckets[b]) sa[pos++] = idx;
        }

        if (n > 1)
        {
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

            int k = 1;
            while (k < n)
            {
                (int, int)[] pairs = new (int, int)[n];
                for (int i = 0; i < n; i++)
                {
                    pairs[i] = (rank[i], rank[(i + k) % n]);
                }

                Array.Sort(sa, (a, b) =>
                {
                    var pairA = pairs[a];
                    var pairB = pairs[b];
                    if (pairA.Item1 != pairB.Item1) return pairA.Item1.CompareTo(pairB.Item1);
                    return pairA.Item2.CompareTo(pairB.Item2);
                });

                int[] newRank = new int[n];
                newRank[sa[0]] = 0;
                for (int i = 1; i < n; i++)
                {
                    var prevPair = pairs[sa[i - 1]];
                    var currPair = pairs[sa[i]];
                    newRank[sa[i]] = newRank[sa[i - 1]] + (prevPair != currPair ? 1 : 0);
                }

                Array.Copy(newRank, rank, n);
                k *= 2;
            }
        }

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

    public byte[] BwtInverse(BWTResult bwtResult)
    {
        byte[] bwt = bwtResult.Transformed;
        int n = bwt.Length;
        if (n == 0) return Array.Empty<byte>();

        int[] counts = new int[256];
        foreach (byte b in bwt) counts[b]++;

        int[] positions = new int[256];
        int total = 0;
        for (int i = 0; i < 256; i++)
        {
            positions[i] = total;
            total += counts[i];
        }

        int[] next = new int[n];
        int[] tempCounts = new int[256];

        for (int i = 0; i < n; i++)
        {
            int byteIdx = bwt[i];
            int pos = positions[byteIdx] + tempCounts[byteIdx];
            next[pos] = i;
            tempCounts[byteIdx]++;
        }

        byte[] result = new byte[n];
        int idx = bwtResult.OriginalIdx;

        for (int i = 0; i < n; i++)
        {
            idx = next[idx];
            result[i] = bwt[idx];
        }

        return result;
    }

    public class HuffmanNode : IComparable<HuffmanNode>
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

        public int CompareTo(HuffmanNode? other) => Frequency.CompareTo(other?.Frequency);
    }

    public HuffmanNode BuildHuffmanTree(int[] frequencies)
    {
        var heap = new PriorityQueue<HuffmanNode, int>();

        for (int i = 0; i < frequencies.Length; i++)
        {
            if (frequencies[i] > 0)
            {
                heap.Enqueue(new HuffmanNode(frequencies[i], (byte)i), frequencies[i]);
            }
        }

        if (heap.Count == 1)
        {
            var node = heap.Dequeue();
            return new HuffmanNode(node.Frequency, null, false, node, new HuffmanNode(0, 0));
        }

        while (heap.Count > 1)
        {
            var left = heap.Dequeue();
            var right = heap.Dequeue();

            var parent = new HuffmanNode(left.Frequency + right.Frequency, null, false, left, right);

            heap.Enqueue(parent, parent.Frequency);
        }

        return heap.Dequeue();
    }

    public class HuffmanCodes
    {
        public int[] CodeLengths { get; } = new int[256];
        public int[] Codes { get; } = new int[256];
    }

    public void BuildHuffmanCodes(HuffmanNode node, int code = 0, int length = 0, HuffmanCodes? huffmanCodes = null)
    {
        huffmanCodes ??= new HuffmanCodes();

        if (node.IsLeaf && node.ByteVal != 0)
        {
            int idx = node.ByteVal!.Value;
            huffmanCodes.CodeLengths[idx] = length;
            huffmanCodes.Codes[idx] = code;
        }
        else
        {
            if (node.Left != null) BuildHuffmanCodes(node.Left, code << 1, length + 1, huffmanCodes);
            if (node.Right != null) BuildHuffmanCodes(node.Right, (code << 1) | 1, length + 1, huffmanCodes);
        }
    }

    public class EncodedResult
    {
        public byte[] Data { get; }
        public int BitCount { get; }

        public EncodedResult(byte[] data, int bitCount)
        {
            Data = data;
            BitCount = bitCount;
        }
    }

    public EncodedResult HuffmanEncode(byte[] data, HuffmanCodes huffmanCodes)
    {
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

            for (int i = length - 1; i >= 0; i--)
            {
                if ((code & (1 << i)) != 0) currentByte |= (byte)(1 << (7 - bitPos));
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

        if (bitPos > 0) result[byteIndex++] = currentByte;

        return new EncodedResult(result[0..byteIndex], totalBits);
    }

    public byte[] HuffmanDecode(byte[] encoded, HuffmanNode root, int bitCount)
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

                if (currentNode.IsLeaf && currentNode.ByteVal != 0)
                {
                    result.Add(currentNode.ByteVal!.Value);
                    currentNode = root;
                }
            }
        }

        return result.ToArray();
    }

    public class CompressedData
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

    public CompressedData Compress(byte[] data)
    {
        BWTResult bwtResult = BwtTransform(data);

        int[] frequencies = new int[256];
        foreach (byte b in bwtResult.Transformed) frequencies[b]++;

        HuffmanNode huffmanTree = BuildHuffmanTree(frequencies);

        HuffmanCodes huffmanCodes = new HuffmanCodes();
        BuildHuffmanCodes(huffmanTree, huffmanCodes: huffmanCodes);

        EncodedResult encoded = HuffmanEncode(bwtResult.Transformed, huffmanCodes);

        return new CompressedData(bwtResult, frequencies, encoded.Data, encoded.BitCount);
    }

    public byte[] Decompress(CompressedData compressed)
    {
        HuffmanNode huffmanTree = BuildHuffmanTree(compressed.Frequencies);

        byte[] decoded = HuffmanDecode(compressed.EncodedBits, huffmanTree, compressed.OriginalBitCount);

        BWTResult bwtResult = new BWTResult(decoded, compressed.BwtResult.OriginalIdx);

        return BwtInverse(bwtResult);
    }

    public int _size;
    public byte[] _testData = Array.Empty<byte>();
    public uint _result;

    public BWTHuffEncode()
    {
        _result = 0;
        _size = (int)ConfigVal("size");
    }

    public byte[] GenerateTestData(int size)
    {
        byte[] pattern = "ABRACADABRA"u8.ToArray();
        byte[] data = new byte[size];

        for (int i = 0; i < size; i++) data[i] = pattern[i % pattern.Length];

        return data;
    }

    public override void Prepare() => _testData = GenerateTestData(_size);

    public override void Run(long IterationId)
    {
        CompressedData compressed = Compress(_testData);
        _result += (uint)compressed.EncodedBits.Length;
    }

    public override uint Checksum => _result;
}