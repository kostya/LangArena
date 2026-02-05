using System.Text.Json;
using System.Text.Json.Nodes;

public class JsonParseDom : Benchmark
{
    private long _n;
    private string _text = "";
    private uint _result;

    public JsonParseDom()
    {
        _result = 0;
        _n = ConfigVal("coords");
    }

    public override void Prepare()
    {
        var jsonGen = new JsonGenerate();
        jsonGen._n = _n;
        jsonGen.Prepare();
        jsonGen.Run(0);
        _text = jsonGen.GetJson();
    }

    private (double x, double y, double z) Calc(string text)
    {
        JsonNode? root = JsonNode.Parse(text);
        if (root == null) return (0, 0, 0);

        JsonArray? coordinates = root["coordinates"]?.AsArray();
        if (coordinates == null) return (0, 0, 0);

        double len = coordinates.Count;
        double x = 0, y = 0, z = 0;

        foreach (var coord in coordinates)
        {
            if (coord == null) continue;

            x += coord["x"]?.GetValue<double>() ?? 0;
            y += coord["y"]?.GetValue<double>() ?? 0;
            z += coord["z"]?.GetValue<double>() ?? 0;
        }

        return (x / len, y / len, z / len);
    }

    public override void Run(long IterationId)
    {
        var (x, y, z) = Calc(_text);
        _result += Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z);
    }

    public override uint Checksum => _result;
}