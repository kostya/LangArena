using System.Numerics;
using System.Text;

public class Pidigits : Benchmark
{
    private int _nn;
    private StringBuilder _resultBuilder;
    
    public override long Result => Helper.Checksum(_resultBuilder.ToString());
    
    public Pidigits()
    {
        _resultBuilder = new StringBuilder();
    }
    
    public override void Prepare()
    {
        var className = nameof(Pidigits);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _nn = iter;
                return;
            }
        }
        _nn = 1;
        Console.WriteLine($"Warning: Using default iterations for {className}");
    }
    
    public override void Run()
    {
        int i = 0;
        int k = 0;
        ulong ns = 0; // Изменено на ulong для 10 цифр
        BigInteger a = 0;
        BigInteger t;
        BigInteger u;
        int k1 = 1;
        BigInteger n = 1;
        BigInteger d = 1;
        
        while (true)
        {
            k += 1;
            t = n << 1; // BigInteger shift
            n *= k;
            k1 += 2;
            a = (a + t) * k1;
            d *= k1;
            
            if (a >= n)
            {
                var temp = n * 3 + a;
                var quotient = temp / d;
                t = quotient; // BigInteger
                u = temp % d;
                u += n;
                
                if (d > u)
                {
                    ns = ns * 10 + (ulong)t; // Приведение к ulong
                    i += 1;
                    
                    if (i % 10 == 0)
                    {
                        _resultBuilder.AppendFormat("{0:D10}\t:{1}\n", ns, i);
                        ns = 0;
                    }
                    
                    if (i >= _nn)
                        break;
                    
                    a = (a - (d * t)) * 10;
                    n *= 10;
                }
            }
        }
        
        // Добавляем оставшиеся цифры
        if (ns != 0)
        {
            _resultBuilder.AppendFormat("{0:D10}\t:{1}\n", ns, i);
        }
    }
}