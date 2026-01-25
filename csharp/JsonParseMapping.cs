using System.Text.Json;

public class JsonParseMapping : Benchmark
{
    private string _text = "";
    private uint _result;
    
    public override long Result => _result;
    
    public override void Prepare()
    {
        var jsonGen = new JsonGenerate();
        jsonGen._n = Iterations;
        jsonGen.Prepare();
        jsonGen.Run();
        _text = jsonGen.GetJson();
    }
    
    public override void Run()
    {
        var (x, y, z) = CalcWithReader(_text);
        unchecked
        {
            _result = Helper.Checksum(x) + Helper.Checksum(y) + Helper.Checksum(z);
        }
    }
    
    private (double x, double y, double z) CalcWithReader(string json)
    {
        double sumX = 0, sumY = 0, sumZ = 0;
        int count = 0;
        
        // Читаем как UTF8 байты (без создания DOM)
        byte[] data = System.Text.Encoding.UTF8.GetBytes(json);
        var reader = new Utf8JsonReader(data);
        
        // Ищем поле "coordinates"
        while (reader.Read())
        {
            if (reader.TokenType == JsonTokenType.PropertyName &&
                reader.ValueTextEquals("coordinates"))
            {
                // Входим в массив
                reader.Read(); // StartArray
                
                // Читаем все объекты в массиве
                while (reader.TokenType != JsonTokenType.EndArray)
                {
                    if (reader.TokenType == JsonTokenType.StartObject)
                    {
                        double x = 0, y = 0, z = 0;
                        bool hasX = false, hasY = false, hasZ = false;
                        
                        // Читаем один объект координаты
                        while (reader.TokenType != JsonTokenType.EndObject)
                        {
                            reader.Read();
                            if (reader.TokenType == JsonTokenType.PropertyName)
                            {
                                // Проверяем какое поле
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
                                    // Пропускаем ненужные поля
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
                        
                        reader.Read(); // EndObject
                    }
                    else
                    {
                        reader.Read();
                    }
                }
                break; // Нашли coordinates, дальше не нужно
            }
        }
        
        return count > 0 ? (sumX / count, sumY / count, sumZ / count) : (0, 0, 0);
    }
}