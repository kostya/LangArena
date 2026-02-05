using System.Text;

public class Base64Encode : Benchmark
{
    private int _n;
    private string _str = "";
    private string _str2 = "";
    private uint _result;

    public Base64Encode()
    {
        _result = 0;
        _n = (int)ConfigVal("size");
    }

    public override void Prepare()
    {
        _str = new string('a', _n);
        byte[] bytes = Encoding.UTF8.GetBytes(_str);
        _str2 = Convert.ToBase64String(bytes);
    }

    public override void Run(long IterationId) {
        byte[] bytes = Encoding.UTF8.GetBytes(_str);
        _str2 = Convert.ToBase64String(bytes);
        _result += (uint)_str2.Length;
    }

    public override uint Checksum
    {
        get
        {

            string resultStr = $"encode {(_str.Length > 4 ? _str.Substring(0, 4) + "..." : _str)} to {(_str2.Length > 4 ? _str2.Substring(0, 4) + "..." : _str2)}: {_result}";
            return Helper.Checksum(resultStr);
        }
    }
}