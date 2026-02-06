using System.Text.Json;

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
        try
        {
            using var doc = JsonDocument.Parse(text);
            var root = doc.RootElement;

            if (root.TryGetProperty("coordinates", out var coordsElement) && 
                coordsElement.ValueKind == JsonValueKind.Array)
            {
                double x = 0, y = 0, z = 0;
                int count = 0;

                foreach (var coord in coordsElement.EnumerateArray())
                {
                    if (coord.TryGetProperty("x", out var xProp) && 
                        xProp.ValueKind == JsonValueKind.Number)
                        x += xProp.GetDouble();

                    if (coord.TryGetProperty("y", out var yProp) && 
                        yProp.ValueKind == JsonValueKind.Number)
                        y += yProp.GetDouble();

                    if (coord.TryGetProperty("z", out var zProp) && 
                        zProp.ValueKind == JsonValueKind.Number)
                        z += zProp.GetDouble();

                    count++;
                }

                if (count > 0)
                    return (x / count, y / count, z / count);
            }
        }
        catch
        {

        }

        return (0, 0, 0);
    }

    public override void Run(long IterationId)
    {
        var (x, y, z) = Calc(_text);
        _result += Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z);
    }

    public override uint Checksum => _result;
}