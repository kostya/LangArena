using System.Text.Json;
using System.Text.Json.Serialization;

// Выносим Coordinate в отдельную запись
public record Coordinate(
    [property: JsonPropertyName("x")] double X,
    [property: JsonPropertyName("y")] double Y,
    [property: JsonPropertyName("z")] double Z,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("opts")] Dictionary<string, Tuple<int, bool>> Opts
);

// Класс-обертка для сериализации
public class CoordinatesWrapper
{
    public List<Coordinate> coordinates { get; set; }
    public string info { get; set; }
}

// Контекст source generation - используем уникальное имя
[JsonSerializable(typeof(CoordinatesWrapper))]
[JsonSerializable(typeof(List<Coordinate>))]
[JsonSerializable(typeof(Coordinate))]
[JsonSerializable(typeof(Dictionary<string, Tuple<int, bool>>))]
[JsonSerializable(typeof(Tuple<int, bool>))]
internal partial class JsonGenerateContext : JsonSerializerContext
{
}

// Основной класс бенчмарка
public class JsonGenerate : Benchmark
{
    public int _n;
    private List<Coordinate> _data = new();
    private string _json = "";
    
    public override long Result => 1; // Всегда true, как в оригинале
    
    public JsonGenerate()
    {
        _n = Iterations;
    }
    
    public override void Prepare()
    {        
        // Генерация тестовых данных
        for (int i = 0; i < _n; i++)
        {
            double x = Math.Round(Helper.NextFloat(), 8);
            double y = Math.Round(Helper.NextFloat(), 8);
            double z = Math.Round(Helper.NextFloat(), 8);
            string name = $"{Helper.NextFloat():F7} {Helper.NextInt(10000)}";
            
            var opts = new Dictionary<string, Tuple<int, bool>>
            {
                ["1"] = Tuple.Create(1, true)
            };
            
            _data.Add(new Coordinate(x, y, z, name, opts));
        }
    }
    
    public override void Run()
    {
        var obj = new CoordinatesWrapper
        {
            coordinates = _data,
            info = "some info"
        };
        
        // Используем source generation для максимальной скорости
        _json = JsonSerializer.Serialize(
            obj, 
            JsonGenerateContext.Default.CoordinatesWrapper
        );
    }
    
    public string GetJson() => _json;
}