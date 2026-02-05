using System.Text.Json;

public class JsonParseMapping : Benchmark
{
    private string _text = "";
    private uint _result;

    public JsonParseMapping()
    {
        _result = 0;
    }

    public override void Prepare()
    {
        var jsonGen = new JsonGenerate();
        jsonGen._n = ConfigVal("coords");
        jsonGen.Prepare();
        jsonGen.Run(0);
        _text = jsonGen.GetJson();
    }

    public override void Run(long IterationId)
    {
        var (x, y, z) = CalcWithReader(_text);
        _result += Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z);
    }

    public override uint Checksum => _result;

    private (double x, double y, double z) CalcWithReader(string json)
    {
        double sumX = 0, sumY = 0, sumZ = 0;
        int count = 0;

        byte[] data = System.Text.Encoding.UTF8.GetBytes(json);
        var reader = new Utf8JsonReader(data);

        while (reader.Read())
        {
            if (reader.TokenType == JsonTokenType.PropertyName && reader.ValueTextEquals("coordinates"))
            {
                reader.Read();

                while (reader.TokenType != JsonTokenType.EndArray)
                {
                    if (reader.TokenType == JsonTokenType.StartObject)
                    {
                        double x = 0, y = 0, z = 0;
                        bool hasX = false, hasY = false, hasZ = false;

                        while (reader.TokenType != JsonTokenType.EndObject)
                        {
                            reader.Read();
                            if (reader.TokenType == JsonTokenType.PropertyName)
                            {
                                if (reader.ValueTextEquals("x"))
                                {
                                    reader.Read();
                                    x = reader.GetDouble();
                                    hasX = true;
                                }
                                else if (reader.ValueTextEquals("y"))
                                {
                                    reader.Read();
                                    y = reader.GetDouble();
                                    hasY = true;
                                }
                                else if (reader.ValueTextEquals("z"))
                                {
                                    reader.Read();
                                    z = reader.GetDouble();
                                    hasZ = true;
                                }
                                else
                                {
                                    reader.Read();
                                    reader.Skip();
                                }
                            }
                        }

                        if (hasX && hasY && hasZ)
                        {
                            sumX += x;
                            sumY += y;
                            sumZ += z;
                            count++;
                        }

                        reader.Read();
                    }
                    else reader.Read();
                }
                break;
            }
        }

        return count > 0 ? (sumX / count, sumY / count, sumZ / count) : (0, 0, 0);
    }
}