using System.Text;

public class Base64Encode : Benchmark
{
    private int _n;
    private byte[] str1bytes;
    private string _str2 = "";
    private uint _result;

    public Base64Encode()
    {
        _result = 0;
        _n = (int)ConfigVal("size");
    }

    public override void Prepare()
    {
        string _str = new string('a', _n);
        str1bytes = Encoding.UTF8.GetBytes(_str);
        _str2 = Convert.ToBase64String(str1bytes);
    }

    public override void Run(long IterationId) {
        _str2 = Convert.ToBase64String(str1bytes);
        _result += (uint)_str2.Length;
    }

    public override uint Checksum
    {
        get
        {
            string _str = Encoding.UTF8.GetString(str1bytes);
            string resultStr = $"encode {(_str.Length > 4 ? _str.Substring(0, 4) + "..." : _str)} to {(_str2.Length > 4 ? _str2.Substring(0, 4) + "..." : _str2)}: {_result}";
            return Helper.Checksum(resultStr);
        }
    }
}