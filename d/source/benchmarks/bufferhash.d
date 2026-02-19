module benchmarks.bufferhash;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.range;
import std.random;
import benchmark;
import helper;

class BufferHashBenchmark : Benchmark
{
protected:
    ubyte[] data;
    int sizeVal;
    uint resultVal;

    this()
    {
        resultVal = 0;
        sizeVal = 0;
    }

    abstract uint test();

protected:
    override string className() const
    {
        return "BufferHashBenchmark";
    }

public:
    override void prepare()
    {
        if (sizeVal == 0)
        {
            sizeVal = configVal("size");
            data.length = sizeVal;

            foreach (i; 0 .. sizeVal)
            {
                data[i] = cast(ubyte) Helper.nextInt(256);
            }
        }
    }

    override void run(int iterationId)
    {
        resultVal += test();
    }

    override uint checksum()
    {
        return resultVal;
    }
}

class BufferHashSHA256 : BufferHashBenchmark
{
private:
    static ubyte[32] simpleSHA256(const ubyte[] data)
    {
        ubyte[32] result;

        uint[8] hashes = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f,
            0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ];

        foreach (i, ref d; data)
        {
            auto idx = i & 7;
            uint h = hashes[idx];
            h = ((h << 5) + h) + d;
            h = (h + (h << 10)) ^ (h >> 6);
            hashes[idx] = h;
        }

        foreach (i; 0 .. 8)
        {
            result[i * 4] = cast(ubyte)(hashes[i] >> 24);
            result[i * 4 + 1] = cast(ubyte)(hashes[i] >> 16);
            result[i * 4 + 2] = cast(ubyte)(hashes[i] >> 8);
            result[i * 4 + 3] = cast(ubyte)(hashes[i]);
        }

        return result;
    }

protected:
    override string className() const
    {
        return "BufferHashSHA256";
    }

public:
    override uint test()
    {
        auto bytes = simpleSHA256(data);

        return *cast(uint*) bytes.ptr;
    }
}

class BufferHashCRC32 : BufferHashBenchmark
{
private:
    uint crc32(const ubyte[] data)
    {
        uint crc = 0xFFFFFFFFu;

        foreach (b; data)
        {
            crc = crc ^ b;
            foreach (j; 0 .. 8)
            {
                if (crc & 1)
                {
                    crc = (crc >> 1) ^ 0xEDB88320u;
                }
                else
                {
                    crc = crc >> 1;
                }
            }
        }
        return crc ^ 0xFFFFFFFFu;
    }

protected:
    override string className() const
    {
        return "BufferHashCRC32";
    }

public:
    override uint test()
    {
        return crc32(data);
    }
}
