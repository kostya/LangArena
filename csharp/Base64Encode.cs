using System.Text;

public class Base64Encode : Benchmark
{
    private const int TRIES = 8192;
    private int _n;
    private string _str = "";
    private string _str2 = "";
    private uint _result;
    
    public override long Result => _result;
    
    public Base64Encode()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Base64Encode);
        if (Helper.Input.TryGetValue(className, out var value))
        {
            if (int.TryParse(value, out var iter))
            {
                _n = iter;
            }
        }
        else
        {
            _n = 1;
        }
        
        _str = new string('a', _n);
        _str2 = Convert.ToBase64String(Encoding.UTF8.GetBytes(_str));
    }
    
    public override void Run()
    {
        long s_encoded = 0;
        
        for (int i = 0; i < TRIES; i++)
        {
            byte[] bytes = Encoding.UTF8.GetBytes(_str);
            string encoded = Convert.ToBase64String(bytes);
            s_encoded += Encoding.UTF8.GetByteCount(encoded);
        }
        
        string resultStr = $"encode {_str[..Math.Min(4, _str.Length)]}... to {_str2[..Math.Min(4, _str2.Length)]}...: {s_encoded}\n";
        _result = Helper.Checksum(resultStr);
    }
}