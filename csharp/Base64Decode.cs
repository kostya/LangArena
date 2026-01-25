using System.Text;

public class Base64Decode : Benchmark
{
    private const int TRIES = 8192;
    private int _n;
    private string _str2 = "";
    private string _str3 = "";
    private uint _result;
    
    public override long Result => _result;
    
    public Base64Decode()
    {
        _result = 0;
    }
    
    public override void Prepare()
    {
        var className = nameof(Base64Decode);
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
        
        string str = new string('a', _n);
        byte[] bytes = Encoding.UTF8.GetBytes(str);
        _str2 = Convert.ToBase64String(bytes);
        _str3 = Encoding.UTF8.GetString(Convert.FromBase64String(_str2));
    }
    
    public override void Run()
    {
        long s_decoded = 0;
        
        for (int i = 0; i < TRIES; i++)
        {
            byte[] decodedBytes = Convert.FromBase64String(_str2);
            s_decoded += decodedBytes.Length;
        }
        
        string resultStr = $"decode {_str2[..Math.Min(4, _str2.Length)]}... to {_str3[..Math.Min(4, _str3.Length)]}...: {s_decoded}\n";
        _result = Helper.Checksum(resultStr);
    }
}