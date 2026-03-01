public class Sieve : Benchmark
{
    private long _limit;
    private uint _checksum;

    public Sieve()
    {
        _limit = ConfigVal("limit");
        _checksum = 0;
    }

    public override void Run(long iterationId)
    {
        int limit = (int)_limit;
        byte[] primes = new byte[limit + 1];
        Array.Fill(primes, (byte)1);
        primes[0] = 0;
        primes[1] = 0;

        int sqrtLimit = (int)Math.Sqrt(limit);

        for (int p = 2; p <= sqrtLimit; p++)
        {
            if (primes[p] == 1)
            {
                for (int multiple = p * p; multiple <= limit; multiple += p)
                {
                    primes[multiple] = 0;
                }
            }
        }

        int lastPrime = 2;
        int count = 1;

        for (int n = 3; n <= limit; n += 2)
        {
            if (primes[n] == 1)
            {
                lastPrime = n;
                count++;
            }
        }

        _checksum += (uint)(lastPrime + count);
    }

    public override uint Checksum => _checksum;
    public override string TypeName => "Etc::Sieve";
}