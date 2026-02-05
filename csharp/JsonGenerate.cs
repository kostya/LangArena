using System.Text.Json;
using System.Text.Json.Serialization;

public record Coordinate(
    [property: JsonPropertyName("x")] double X,
    [property: JsonPropertyName("y")] double Y,
    [property: JsonPropertyName("z")] double Z,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("opts")] Dictionary<string, Tuple<int, bool>> Opts
);

public class CoordinatesWrapper
{
    public List<Coordinate> coordinates { get; set; } = new();
    public string info { get; set; } = "some info";
}

[JsonSerializable(typeof(CoordinatesWrapper))]
[JsonSerializable(typeof(List<Coordinate>))]
[JsonSerializable(typeof(Coordinate))]
[JsonSerializable(typeof(Dictionary<string, Tuple<int, bool>>))]
[JsonSerializable(typeof(Tuple<int, bool>))]
internal partial class JsonGenerateContext : JsonSerializerContext { }

public class JsonGenerate : Benchmark
{
    public long _n;
    private List<Coordinate> _data = new();
    private string _json = "";
    private uint _result;

    public JsonGenerate()
    {
        _n = ConfigVal("coords");
    }

    public override void Prepare()
    {        
        _data.Clear();
        for (int i = 0; i < _n; i++)
        {
            double x = Math.Round(Helper.NextFloat(), 8);
            double y = Math.Round(Helper.NextFloat(), 8);
            double z = Math.Round(Helper.NextFloat(), 8);
            string name = $"{Helper.NextFloat():F7} {Helper.NextInt(10000)}";

            var opts = new Dictionary<string, Tuple<int, bool>> { ["1"] = Tuple.Create(1, true) };
            _data.Add(new Coordinate(x, y, z, name, opts));
        }
    }

    public override void Run(long IterationId)
    {
        var obj = new CoordinatesWrapper { coordinates = _data, info = "some info" };
        _json = JsonSerializer.Serialize(obj, JsonGenerateContext.Default.CoordinatesWrapper);

        if (_json.StartsWith("{\"coordinates\":")) {
            _result++;
        }
    }

    public override uint Checksum
    {
        get { return _result; }
    }

    public string GetJson() => _json;
}