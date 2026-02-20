module benchmarks.pidigits;
import benchmark;
import helper;
import gmp.z;
import std.array;
import std.conv;

class Pidigits : Benchmark
{
private:
    int nn;
    private Appender!string resultApp;

protected:
    override string className() const
    {
        return "Pidigits";
    }

public:
    this()
    {
        nn = configVal("amount");
        resultApp = appender!string();
    }

    override void run(int iterationId)
    {
        int i = 0;
        int k = 0;
        auto ns = MpZ(0);
        auto a = MpZ(0);
        auto t = MpZ(0);
        auto u = MpZ(0);
        int k1 = 1;
        auto n = MpZ(1);
        auto d = MpZ(1);

        while (true)
        {
            k += 1;
            t = n * 2;
            n *= k;
            k1 += 2;
            a = (a + t) * k1;
            d *= k1;

            if (a >= n)
            {
                auto temp = n * 3 + a;
                auto q = temp / d;
                u = temp % d;
                u += n;

                if (d > u)
                {
                    ns = ns * 10 + q;
                    i += 1;

                    if (i % 10 == 0)
                    {
                        string nsStr = ns.toString();
                        if (nsStr.length < 10)
                        {
                            nsStr = replicate("0", 10 - nsStr.length) ~ nsStr;
                        }
                        resultApp.put(nsStr ~ "\t:" ~ i.to!string ~ "\n");
                        ns = MpZ(0);
                    }

                    if (i >= nn)
                        break;

                    a = (a - (d * q)) * 10;
                    n *= 10;
                }
            }
        }
    }

    override uint checksum()
    {
        return Helper.checksum(resultApp.data);
    }
}
