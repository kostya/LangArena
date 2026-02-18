using System.Text;

public class Base64Decode : Benchmark
{
    private int _n;
    private string _str2 = "";
    private byte[] _str3bytes;
    private uint _result;

    public Base64Decode()
    {
        _result = 0;
        _n = (int)ConfigVal("size");
    }

    public override void Prepare()
    {
        string str = new string('a', _n);
        byte[] bytes = Encoding.UTF8.GetBytes(str);
        _str2 = Convert.ToBase64String(bytes);
        _str3bytes = Convert.FromBase64String(_str2);
    }

    public override void Run(long IterationId)
    {
        _str3bytes = Convert.FromBase64String(_str2);
        _result += (uint)_str3bytes.Length;
    }

    public override uint Checksum
    {
        get
        {
            string _str3 = Encoding.UTF8.GetString(_str3bytes);
            string resultStr = $"decode {(_str2.Length > 4 ? _str2.Substring(0, 4) + "..." : _str2)} to {(_str3bytes.Length > 4 ? _str3.Substring(0, 4) + "..." : _str3)}: {_result}";
            return Helper.Checksum(resultStr);
        }
    }
}