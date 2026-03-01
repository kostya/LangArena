module benchmarks.sieve;

import std.stdio;
import std.math;
import std.array;
import benchmark;
import helper;

class Sieve : Benchmark
{
private:
    long limit;
    uint checksumVal;

public:
    this()
    {
        limit = configVal("limit");
        checksumVal = 0;
    }

    override string className() const
    {
        return "Etc::Sieve";
    }

    override void run(int iterationId)
    {
        size_t sz = cast(size_t) limit;
        auto primes = new ubyte[](sz + 1);
        primes[] = 1;
        primes[0] = 0;
        primes[1] = 0;

        size_t sqrtLimit = cast(size_t) sqrt(cast(double) limit);

        for (size_t p = 2; p <= sqrtLimit; ++p)
        {
            if (primes[p] == 1)
            {
                for (size_t multiple = p * p; multiple <= sz; multiple += p)
                {
                    primes[multiple] = 0;
                }
            }
        }

        int lastPrime = 2;
        int count = 1;

        for (size_t n = 3; n <= sz; n += 2)
        {
            if (primes[n] == 1)
            {
                lastPrime = cast(int) n;
                ++count;
            }
        }

        checksumVal += cast(uint)(lastPrime + count);
    }

    override uint checksum()
    {
        return checksumVal;
    }
}
