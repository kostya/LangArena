module helper;

import std.conv;
import std.string;
import std.random;
import std.digest;
import std.digest.crc;
import std.digest.sha;

class Helper
{
private:
    enum long IM = 139968;
    enum long IA = 3877;
    enum long IC = 29573;

    static __gshared long last = 42;

public:
    static void reset()
    {
        last = 42;
    }

    static int nextInt(int max)
    {
        last = (last * IA + IC) % IM;
        return cast(int)((last * max) / IM);
    }

    static int nextInt(int from, int to)
    {
        return nextInt(to - from + 1) + from;
    }

    static double nextFloat(double max = 1.0)
    {
        last = (last * IA + IC) % IM;
        return max * cast(double)(last) / IM;
    }

    static uint checksum(string v)
    {
        uint hash = 5381;
        foreach (c; v)
        {
            hash = ((hash << 5) + hash) + cast(ubyte) c;
        }
        return hash;
    }

    static uint checksum(ubyte[] v)
    {
        uint hash = 5381;
        foreach (b; v)
        {
            hash = ((hash << 5) + hash) + b;
        }
        return hash;
    }

    static uint checksumF64(double v)
    {
        return checksum(format("%.7f", v));
    }

}
