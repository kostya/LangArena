using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Compress
{

    public abstract class CompressBenchmark : Benchmark
    {
        protected byte[] GenerateTestData(long size)
        {
            string pattern = "ABRACADABRA";
            int patternLen = pattern.Length;
            byte[] data = new byte[size];

            for (long i = 0; i < size; i++)
            {
                data[i] = (byte)pattern[(int)(i % patternLen)];
            }

            return data;
        }
    }

    public class BWTEncode : CompressBenchmark
    {
        public struct BWTResult
        {
            public byte[] Transformed { get; set; }
            public int OriginalIdx { get; set; }

            public BWTResult(byte[] transformed, int originalIdx)
            {
                Transformed = transformed;
                OriginalIdx = originalIdx;
            }
        }

        public BWTResult BwtTransform(byte[] input)
        {
            int n = input.Length;
            if (n == 0) return new BWTResult(new byte[0], 0);

            var sa = Enumerable.Range(0, n).ToArray();

            var buckets = new List<int>[256];
            for (int i = 0; i < 256; i++) buckets[i] = new List<int>();

            foreach (int idx in sa) buckets[input[idx]].Add(idx);

            int pos = 0;
            for (int b = 0; b < 256; b++)
            {
                foreach (int idx in buckets[b]) sa[pos++] = idx;
            }

            if (n > 1)
            {
                var rank = new int[n];
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
                    var pairs = new (int, int)[n];
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

                    var newRank = new int[n];
                    newRank[sa[0]] = 0;
                    for (int i = 1; i < n; i++)
                    {
                        var prevPair = pairs[sa[i - 1]];
                        var currPair = pairs[sa[i]];
                        newRank[sa[i]] = newRank[sa[i - 1]] +
                            (prevPair.Item1 != currPair.Item1 || prevPair.Item2 != currPair.Item2 ? 1 : 0);
                    }

                    newRank.CopyTo(rank, 0);
                    k *= 2;
                }
            }

            var transformed = new byte[n];
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

        public long sizeVal;
        private byte[] testData;
        public BWTResult bwtResult;
        private uint resultVal;

        public BWTEncode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            bwtResult = new BWTResult(new byte[0], 0);
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);
        }

        public override void Run(long iterationId)
        {
            bwtResult = BwtTransform(testData);
            resultVal += (uint)bwtResult.Transformed.Length;
        }

        public override uint Checksum => resultVal;
    }

    public class BWTDecode : CompressBenchmark
    {
        private byte[] BwtInverse(BWTEncode.BWTResult bwtResult)
        {
            var bwt = bwtResult.Transformed;
            int n = bwt.Length;
            if (n == 0) return new byte[0];

            var counts = new int[256];
            foreach (byte b in bwt) counts[b]++;

            var positions = new int[256];
            int total = 0;
            for (int i = 0; i < 256; i++)
            {
                positions[i] = total;
                total += counts[i];
            }

            var next = new int[n];
            var tempCounts = new int[256];

            for (int i = 0; i < n; i++)
            {
                byte byteIdx = bwt[i];
                int pos = positions[byteIdx] + tempCounts[byteIdx];
                next[pos] = i;
                tempCounts[byteIdx]++;
            }

            var result = new byte[n];
            int idx = bwtResult.OriginalIdx;

            for (int i = 0; i < n; i++)
            {
                idx = next[idx];
                result[i] = bwt[idx];
            }

            return result;
        }

        private long sizeVal;
        private byte[] testData;
        private byte[] inverted;
        private BWTEncode.BWTResult bwtResult;
        private uint resultVal;

        public BWTDecode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            inverted = new byte[0];
            bwtResult = new BWTEncode.BWTResult(new byte[0], 0);
        }

        public override void Prepare()
        {
            var encoder = new BWTEncode();
            encoder.sizeVal = sizeVal;
            encoder.Prepare();
            encoder.Run(0);
            testData = GenerateTestData(sizeVal);
            bwtResult = encoder.BwtTransform(testData);
        }

        public override void Run(long iterationId)
        {
            inverted = BwtInverse(bwtResult);
            resultVal += (uint)inverted.Length;
        }

        public override uint Checksum
        {
            get
            {
                uint res = resultVal;
                if (inverted.SequenceEqual(testData))
                    res += 100000;
                return res;
            }
        }
    }

    public class HuffEncode : CompressBenchmark
    {
        public class HuffmanNode : IComparable<HuffmanNode>
        {
            public int Frequency { get; set; }
            public byte ByteVal { get; set; }
            public bool IsLeaf { get; set; }
            public HuffmanNode Left { get; set; }
            public HuffmanNode Right { get; set; }

            public HuffmanNode(int freq, byte byteVal = 0, bool leaf = true)
            {
                Frequency = freq;
                ByteVal = byteVal;
                IsLeaf = leaf;
                Left = null;
                Right = null;
            }

            public int CompareTo(HuffmanNode other)
            {
                return Frequency.CompareTo(other.Frequency);
            }
        }

        public struct HuffmanCodes
        {
            public int[] CodeLengths;
            public int[] Codes;

            public HuffmanCodes()
            {
                CodeLengths = new int[256];
                Codes = new int[256];
            }
        }

        public struct EncodedResult
        {
            public byte[] Data;
            public int BitCount;
            public int[] Frequencies;

            public EncodedResult(byte[] data, int bitCount, int[] frequencies)
            {
                Data = data;
                BitCount = bitCount;
                Frequencies = frequencies;
            }
        }

        public static HuffmanNode BuildHuffmanTree(int[] frequencies)
        {
            var nodes = new List<HuffmanNode>();
            for (int i = 0; i < 256; i++)
            {
                if (frequencies[i] > 0)
                {
                    nodes.Add(new HuffmanNode(frequencies[i], (byte)i));
                }
            }

            nodes.Sort((a, b) => a.Frequency.CompareTo(b.Frequency));

            if (nodes.Count == 1)
            {
                var node = nodes[0];
                var root = new HuffmanNode(node.Frequency, 0, false);
                root.Left = node;
                root.Right = new HuffmanNode(0, 0);
                return root;
            }

            while (nodes.Count > 1)
            {
                var left = nodes[0];
                var right = nodes[1];

                nodes.RemoveAt(0);
                nodes.RemoveAt(0);

                var parent = new HuffmanNode(left.Frequency + right.Frequency, 0, false);
                parent.Left = left;
                parent.Right = right;

                int pos = nodes.BinarySearch(parent, Comparer<HuffmanNode>.Create((a, b) => a.Frequency.CompareTo(b.Frequency)));
                if (pos < 0) pos = ~pos;
                nodes.Insert(pos, parent);
            }

            return nodes[0];
        }

        public static void BuildHuffmanCodes(HuffmanNode node, int code, int length, ref HuffmanCodes codes)
        {
            if (node.IsLeaf)
            {
                if (length > 0 || node.ByteVal != 0)
                {
                    int idx = node.ByteVal;
                    codes.CodeLengths[idx] = length;
                    codes.Codes[idx] = code;
                }
            }
            else
            {
                if (node.Left != null) BuildHuffmanCodes(node.Left, code << 1, length + 1, ref codes);
                if (node.Right != null) BuildHuffmanCodes(node.Right, (code << 1) | 1, length + 1, ref codes);
            }
        }

        public static EncodedResult HuffmanEncode(byte[] data, HuffmanCodes codes, int[] frequencies)
        {
            var result = new List<byte>(data.Length * 2);
            byte currentByte = 0;
            int bitPos = 0;
            int totalBits = 0;

            foreach (byte b in data)
            {
                int idx = b;
                int code = codes.Codes[idx];
                int length = codes.CodeLengths[idx];

                for (int i = length - 1; i >= 0; i--)
                {
                    if ((code & (1 << i)) != 0)
                        currentByte |= (byte)(1 << (7 - bitPos));
                    bitPos++;
                    totalBits++;

                    if (bitPos == 8)
                    {
                        result.Add(currentByte);
                        currentByte = 0;
                        bitPos = 0;
                    }
                }
            }

            if (bitPos > 0)
            {
                result.Add(currentByte);
            }

            return new EncodedResult(result.ToArray(), totalBits, frequencies);
        }

        public long sizeVal;
        private byte[] testData;
        public EncodedResult encoded;
        private uint resultVal;

        public HuffEncode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);
        }

        public override void Run(long iterationId)
        {
            var frequencies = new int[256];
            foreach (byte b in testData)
                frequencies[b]++;

            var tree = BuildHuffmanTree(frequencies);

            var codes = new HuffmanCodes();
            BuildHuffmanCodes(tree, 0, 0, ref codes);

            encoded = HuffmanEncode(testData, codes, frequencies);
            resultVal += (uint)encoded.Data.Length;
        }

        public override uint Checksum => resultVal;
    }

    public class HuffDecode : CompressBenchmark
    {
        private byte[] HuffmanDecode(byte[] encoded, HuffEncode.HuffmanNode root, int bitCount)
        {

            byte[] result = new byte[bitCount];
            int resultSize = 0;

            var currentNode = root;
            int bitsProcessed = 0;
            int byteIndex = 0;

            while (bitsProcessed < bitCount && byteIndex < encoded.Length)
            {
                byte byteVal = encoded[byteIndex++];

                for (int bitPos = 7; bitPos >= 0 && bitsProcessed < bitCount; bitPos--)
                {
                    bool bit = ((byteVal >> bitPos) & 1) == 1;
                    currentNode = bit ? currentNode.Right : currentNode.Left;
                    bitsProcessed++;

                    if (currentNode.IsLeaf)
                    {
                        result[resultSize++] = currentNode.ByteVal;
                        currentNode = root;
                    }
                }
            }

            if (resultSize < result.Length)
            {
                Array.Resize(ref result, resultSize);
            }

            return result;
        }

        private long sizeVal;
        private byte[] testData;
        private byte[] decoded;
        private HuffEncode.EncodedResult encoded;
        private uint resultVal;

        public HuffDecode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);

            var encoder = new HuffEncode();
            encoder.sizeVal = sizeVal;
            encoder.Prepare();
            encoder.Run(0);
            encoded = encoder.encoded;
        }

        public override void Run(long iterationId)
        {
            var tree = HuffEncode.BuildHuffmanTree(encoded.Frequencies);
            decoded = HuffmanDecode(encoded.Data, tree, encoded.BitCount);
            resultVal += (uint)decoded.Length;
        }

        public override uint Checksum
        {
            get
            {
                uint res = resultVal;
                if (decoded.SequenceEqual(testData))
                    res += 100000;
                return res;
            }
        }
    }

    public class ArithEncode : CompressBenchmark
    {
        public struct ArithEncodedResult
        {
            public byte[] Data;
            public int BitCount;
            public int[] Frequencies;

            public ArithEncodedResult(byte[] data, int bitCount, int[] frequencies)
            {
                Data = data;
                BitCount = bitCount;
                Frequencies = frequencies;
            }
        }

        public class ArithFreqTable
        {
            public int Total;
            public int[] Low;
            public int[] High;

            public ArithFreqTable(int[] frequencies)
            {
                Total = 0;
                foreach (int f in frequencies) Total += f;

                Low = new int[256];
                High = new int[256];

                int cum = 0;
                for (int i = 0; i < 256; i++)
                {
                    Low[i] = cum;
                    cum += frequencies[i];
                    High[i] = cum;
                }
            }
        }

        public class BitOutputStream
        {
            private int buffer = 0;
            private int bitPos = 0;
            private List<byte> bytes = new List<byte>();
            private int bitsWritten = 0;

            public void WriteBit(int bit)
            {
                buffer = (buffer << 1) | (bit & 1);
                bitPos++;
                bitsWritten++;

                if (bitPos == 8)
                {
                    bytes.Add((byte)buffer);
                    buffer = 0;
                    bitPos = 0;
                }
            }

            public byte[] Flush()
            {
                if (bitPos > 0)
                {
                    buffer <<= (8 - bitPos);
                    bytes.Add((byte)buffer);
                }
                return bytes.ToArray();
            }

            public int BitsWritten => bitsWritten;
        }

        private ArithEncodedResult ArithEncodeImpl(byte[] data)
        {
            var frequencies = new int[256];
            foreach (byte b in data)
                frequencies[b]++;

            var freqTable = new ArithFreqTable(frequencies);

            ulong low = 0;
            ulong high = 0xFFFFFFFF;
            int pending = 0;
            var output = new BitOutputStream();

            foreach (byte b in data)
            {
                int idx = b;
                ulong range = high - low + 1;

                high = low + (range * (ulong)freqTable.High[idx] / (ulong)freqTable.Total) - 1;
                low = low + (range * (ulong)freqTable.Low[idx] / (ulong)freqTable.Total);

                while (true)
                {
                    if (high < 0x80000000)
                    {
                        output.WriteBit(0);
                        for (int i = 0; i < pending; i++) output.WriteBit(1);
                        pending = 0;
                    }
                    else if (low >= 0x80000000)
                    {
                        output.WriteBit(1);
                        for (int i = 0; i < pending; i++) output.WriteBit(0);
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
                output.WriteBit(0);
                for (int i = 0; i < pending; i++) output.WriteBit(1);
            }
            else
            {
                output.WriteBit(1);
                for (int i = 0; i < pending; i++) output.WriteBit(0);
            }

            return new ArithEncodedResult(output.Flush(), output.BitsWritten, frequencies);
        }

        public long sizeVal;
        private byte[] testData;
        public ArithEncodedResult encoded;
        private uint resultVal;

        public ArithEncode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            encoded = new ArithEncodedResult(new byte[0], 0, new int[0]);
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);
        }

        public override void Run(long iterationId)
        {
            encoded = ArithEncodeImpl(testData);
            resultVal += (uint)encoded.Data.Length;
        }

        public override uint Checksum => resultVal;
    }

    public class ArithDecode : CompressBenchmark
    {
        public class BitInputStream
        {
            private byte[] bytes;
            private int bytePos = 0;
            private int bitPos = 0;
            private byte currentByte;

            public BitInputStream(byte[] bytes)
            {
                this.bytes = bytes;
                currentByte = bytes.Length > 0 ? bytes[0] : (byte)0;
            }

            public int ReadBit()
            {
                if (bitPos == 8)
                {
                    bytePos++;
                    bitPos = 0;
                    currentByte = bytePos < bytes.Length ? bytes[bytePos] : (byte)0;
                }

                int bit = (currentByte >> (7 - bitPos)) & 1;
                bitPos++;
                return bit;
            }
        }

        private byte[] ArithDecodeImpl(ArithEncode.ArithEncodedResult encoded)
        {
            var frequencies = encoded.Frequencies;
            int total = frequencies.Sum();
            int dataSize = total;

            var lowTable = new int[256];
            var highTable = new int[256];
            int cum = 0;
            for (int i = 0; i < 256; i++)
            {
                lowTable[i] = cum;
                cum += frequencies[i];
                highTable[i] = cum;
            }

            var result = new byte[dataSize];
            var input = new BitInputStream(encoded.Data);

            ulong value = 0;
            for (int i = 0; i < 32; i++)
                value = (value << 1) | (ulong)input.ReadBit();

            ulong low = 0;
            ulong high = 0xFFFFFFFF;

            for (int j = 0; j < dataSize; j++)
            {
                ulong range = high - low + 1;
                ulong scaled = ((value - low + 1) * (ulong)total - 1) / range;

                int symbol = 0;
                while (symbol < 255 && (ulong)highTable[symbol] <= scaled)
                    symbol++;

                result[j] = (byte)symbol;

                high = low + (range * (ulong)highTable[symbol] / (ulong)total) - 1;
                low = low + (range * (ulong)lowTable[symbol] / (ulong)total);

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
                    value = (value << 1) | (ulong)input.ReadBit();
                }
            }

            return result;
        }

        private long sizeVal;
        private byte[] testData;
        private byte[] decoded;
        private ArithEncode.ArithEncodedResult encoded;
        private uint resultVal;

        public ArithDecode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            decoded = new byte[0];
            encoded = new ArithEncode.ArithEncodedResult(new byte[0], 0, new int[0]);
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);

            var encoder = new ArithEncode();
            encoder.sizeVal = sizeVal;
            encoder.Prepare();
            encoder.Run(0);
            encoded = encoder.encoded;
        }

        public override void Run(long iterationId)
        {
            decoded = ArithDecodeImpl(encoded);
            resultVal += (uint)decoded.Length;
        }

        public override uint Checksum
        {
            get
            {
                uint res = resultVal;
                if (decoded.SequenceEqual(testData))
                    res += 100000;
                return res;
            }
        }
    }

    public class LZWEncode : CompressBenchmark
    {
        public struct LZWResult
        {
            public byte[] Data;
            public int DictSize;

            public LZWResult(byte[] data, int dictSize)
            {
                Data = data;
                DictSize = dictSize;
            }
        }

        private LZWResult LZWEncodeImpl(byte[] input)
        {
            if (input.Length == 0) return new LZWResult(new byte[0], 256);

            var dict = new Dictionary<string, int>(4096);
            for (int i = 0; i < 256; i++)
            {
                dict[((char)i).ToString()] = i;
            }

            int nextCode = 256;

            using var result = new MemoryStream(input.Length * 2);

            string current = ((char)input[0]).ToString();

            for (int i = 1; i < input.Length; i++)
            {
                string nextChar = ((char)input[i]).ToString();
                string newStr = current + nextChar;

                if (dict.ContainsKey(newStr))
                {
                    current = newStr;
                }
                else
                {
                    int code = dict[current];
                    result.WriteByte((byte)((code >> 8) & 0xFF));
                    result.WriteByte((byte)(code & 0xFF));

                    dict[newStr] = nextCode++;
                    current = nextChar;
                }
            }

            int lastCode = dict[current];
            result.WriteByte((byte)((lastCode >> 8) & 0xFF));
            result.WriteByte((byte)(lastCode & 0xFF));

            return new LZWResult(result.ToArray(), nextCode);
        }

        public long sizeVal;
        private byte[] testData;
        public LZWResult encoded;
        private uint resultVal;

        public LZWEncode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            encoded = new LZWResult(new byte[0], 256);
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);
        }

        public override void Run(long iterationId)
        {
            encoded = LZWEncodeImpl(testData);
            resultVal += (uint)encoded.Data.Length;
        }

        public override uint Checksum => resultVal;
    }

    public class LZWDecode : CompressBenchmark
    {
        private byte[] LZWDecodeImpl(LZWEncode.LZWResult encoded)
        {
            if (encoded.Data.Length == 0) return new byte[0];

            var dict = new List<string>(4096);
            for (int i = 0; i < 256; i++)
            {
                dict.Add(((char)i).ToString());
            }

            using var result = new MemoryStream(encoded.Data.Length * 2);

            var data = encoded.Data;
            int pos = 0;

            int high = data[pos];
            int low = data[pos + 1];
            int oldCode = (high << 8) | low;
            pos += 2;

            string oldStr = dict[oldCode];
            byte[] oldBytes = Encoding.UTF8.GetBytes(oldStr);
            result.Write(oldBytes, 0, oldBytes.Length);

            int nextCode = 256;

            while (pos < data.Length)
            {
                high = data[pos];
                low = data[pos + 1];
                int newCode = (high << 8) | low;
                pos += 2;

                string newStr;
                if (newCode < dict.Count)
                {
                    newStr = dict[newCode];
                }
                else if (newCode == nextCode)
                {
                    newStr = dict[oldCode] + dict[oldCode][0];
                }
                else
                {
                    throw new Exception("Error decode");
                }

                byte[] newBytes = Encoding.UTF8.GetBytes(newStr);
                result.Write(newBytes, 0, newBytes.Length);

                dict.Add(dict[oldCode] + newStr[0]);
                nextCode++;

                oldCode = newCode;
            }

            return result.ToArray();
        }

        private long sizeVal;
        private byte[] testData;
        private byte[] decoded;
        private LZWEncode.LZWResult encoded;
        private uint resultVal;

        public LZWDecode()
        {
            sizeVal = ConfigVal("size");
            resultVal = 0;
            testData = new byte[0];
            decoded = new byte[0];
            encoded = new LZWEncode.LZWResult(new byte[0], 256);
        }

        public override void Prepare()
        {
            testData = GenerateTestData(sizeVal);

            var encoder = new LZWEncode();
            encoder.sizeVal = sizeVal;
            encoder.Prepare();
            encoder.Run(0);
            encoded = encoder.encoded;
        }

        public override void Run(long iterationId)
        {
            decoded = LZWDecodeImpl(encoded);
            resultVal += (uint)decoded.Length;
        }

        public override uint Checksum
        {
            get
            {
                uint res = resultVal;
                if (decoded.SequenceEqual(testData))
                    res += 100000;
                return res;
            }
        }
    }

}