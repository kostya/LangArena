public class Fannkuchredux : Benchmark
{
    private int _n;
    private long _result;
    
    public override long Result => _result;
    
    public Fannkuchredux()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Fannkuchredux);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
                return;
            }
        }
        _n = 1;
    }
    
    private (int checksum, int maxFlipsCount) FannkuchreduxAlgo(int n)
    {
        Span<int> perm1 = stackalloc int[32];
        Span<int> perm = stackalloc int[32];
        Span<int> count = stackalloc int[32];
        
        for (int i = 0; i < n; i++) perm1[i] = i;
        
        int maxFlipsCount = 0;
        int permCount = 0;
        int checksum = 0;
        int r = n;
        
        while (true)
        {
            while (r > 1)
            {
                count[r - 1] = r;
                r--;
            }
            
            perm1[..n].CopyTo(perm);
            int flipsCount = 0;
            
            // Первый элемент массива
            while (perm[0] != 0)
            {
                int k = perm[0];
                int k2 = (k + 1) >> 1;
                
                for (int i = 0; i < k2; i++)
                {
                    int j = k - i;
                    (perm[i], perm[j]) = (perm[j], perm[i]); // swap
                }
                
                flipsCount++;
            }
            
            if (flipsCount > maxFlipsCount)
                maxFlipsCount = flipsCount;
            
            checksum += (permCount % 2 == 0) ? flipsCount : -flipsCount;
            
            while (true)
            {
                if (r == n)
                    return (checksum, maxFlipsCount);
                
                int perm0 = perm1[0];
                for (int i = 0; i < r; i++)
                {
                    int j = i + 1;
                    (perm1[i], perm1[j]) = (perm1[j], perm1[i]); // swap
                }
                
                perm1[r] = perm0;
                int cntr = --count[r];
                
                if (cntr > 0)
                    break;
                    
                r++;
            }
            
            permCount++;
        }
    }
    
    public override void Run()
    {
        var (checksum, maxFlipsCount) = FannkuchreduxAlgo(_n);
        unchecked
        {
            _result = (long)checksum * 100 + maxFlipsCount;
        }
    }
}