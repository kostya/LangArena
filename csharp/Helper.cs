using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

public static class Helper
{
    private const long IM = 139968;
    private const long IA = 3877;
    private const long IC = 29573;
    private const int INIT = 42;

    private static long s_last = INIT;

    private static JsonNode? s_config = null;
    private static List<string> s_order = new List<string>();

    public static JsonNode? Config => s_config;
    public static List<string> Order => s_order;

    public static long Last
    {
        get => s_last;
        set => s_last = value;
    }

    public static void Reset()
    {
        s_last = INIT;
    }

    public static int NextInt(int max)
    {
        s_last = (s_last * IA + IC) % IM;
        return (int)((double)s_last / IM * max);
    }

    public static int NextInt(int from, int to)
    {
        return NextInt(to - from + 1) + from;
    }

    public static double NextFloat(double max = 1.0)
    {
        s_last = (s_last * IA + IC) % IM;
        return max * s_last / (double)IM;
    }

    public static uint Checksum(string v)
    {
        uint hash = 5381;
        foreach (byte b in Encoding.UTF8.GetBytes(v))
        {
            hash = ((hash << 5) + hash) + b;
        }
        return hash;
    }

    public static uint Checksum(byte[] bytes)
    {
        uint hash = 5381;
        foreach (byte b in bytes)
        {
            hash = ((hash << 5) + hash) + b;
        }
        return hash;
    }

    public static uint Checksum(double v)
    {
        return Checksum(v.ToString("F7"));
    }

    public static long Config_i64(string className, string fieldName)
    {
        try
        {
            if (s_config == null)
            {
                Console.WriteLine($"Config not loaded for {className}, field: {fieldName}");
                return 0;
            }

            var benchObj = s_config[className] as JsonObject;
            if (benchObj != null)
            {

                if (benchObj.TryGetPropertyValue(fieldName, out var value) && value != null)
                {

                    if (value is JsonValue jsonValue)
                    {
                        if (jsonValue.TryGetValue<long>(out var longValue))
                            return longValue;

                        if (jsonValue.TryGetValue<int>(out var intValue))
                            return intValue;
                    }
                }
            }

            Console.WriteLine($"Config not found for {className}, field: {fieldName}");
            return 0;
        }
        catch (Exception e)
        {
            Console.WriteLine($"Error accessing config for {className}.{fieldName}: {e.Message}");
            return 0;
        }
    }

    public static string Config_s(string className, string fieldName)
    {
        try
        {
            if (s_config == null)
            {
                Console.WriteLine($"Config not loaded for {className}, field: {fieldName}");
                return "";
            }

            var benchObj = s_config[className] as JsonObject;
            if (benchObj != null)
            {

                if (benchObj.TryGetPropertyValue(fieldName, out var value) && value != null)
                {

                    if (value is JsonValue jsonValue)
                    {
                        if (jsonValue.TryGetValue<string>(out var stringValue))
                            return stringValue ?? "";
                    }

                    return value.ToString() ?? "";
                }
            }

            Console.WriteLine($"Config not found for {className}, field: {fieldName}");
            return "";
        }
        catch (Exception e)
        {
            Console.WriteLine($"Error accessing config for {className}.{fieldName}: {e.Message}");
            return "";
        }
    }

    public static void LoadConfig(string filename)
    {
        if (!File.Exists(filename))
        {
            Console.WriteLine($"Error: Config file not found: {filename}");
            s_config = new JsonObject();
            return;
        }

        try
        {
            var jsonText = File.ReadAllText(filename);
            var jsonArray = JsonNode.Parse(jsonText) as JsonArray;

            if (jsonArray == null)
            {
                Console.WriteLine("Error: Config is not an array");
                s_config = new JsonObject();
                return;
            }

            var dict = new JsonObject();
            s_order.Clear();

            foreach (var item in jsonArray)
            {
                if (item == null) continue;

                var itemObj = item as JsonObject;
                if (itemObj == null) continue;

                var nameNode = itemObj["name"];
                var name = nameNode?.GetValue<string>();

                if (!string.IsNullOrEmpty(name))
                {
                    dict[name] = itemObj.DeepClone();
                    s_order.Add(name);
                }
            }

            s_config = dict;
            Console.WriteLine($"Loaded {s_order.Count} benchmarks from config");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error parsing JSON config: {ex.Message}");
            s_config = new JsonObject();
        }
    }
}