using System.Text;
using System.Text.Json;

public static class Helper
{
    private const long IM = 139968;
    private const long IA = 3877;
    private const long IC = 29573;
    private const int INIT = 42;

    private static long s_last = INIT;

    private static JsonDocument? s_config = null;

    public static JsonDocument Config
    {
        get => s_config ?? JsonDocument.Parse("{}");
    }

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
            if (Config.RootElement.TryGetProperty(className, out var benchObj))
            {
                if (benchObj.TryGetProperty(fieldName, out var value))
                {
                    return value.GetInt64();
                }
            }
            throw new InvalidOperationException($"Config not found for {className}, field: {fieldName}");
        }
        catch (Exception e)
        {
            Console.WriteLine(e.Message);
            return 0;
        }
    }

    public static string Config_s(string className, string fieldName)
    {
        try
        {
            if (Config.RootElement.TryGetProperty(className, out var benchObj))
            {
                if (benchObj.TryGetProperty(fieldName, out var value))
                {
                    return value.GetString() ?? "";
                }
            }
            throw new InvalidOperationException($"Config not found for {className}, field: {fieldName}");
        }
        catch (Exception e)
        {
            Console.WriteLine(e.Message);
            return "";
        }
    }

    public static void LoadConfig(string? filename = null)
    {
        filename ??= "test.js";

        if (!File.Exists(filename))
        {

            var alternatives = new[]
            {
                Path.Combine("../", filename),
                Path.Combine("../../", filename),
                Path.GetFileName(filename)
            };

            foreach (var alt in alternatives)
            {
                if (File.Exists(alt))
                {
                    filename = alt;
                    break;
                }
            }
        }

        if (!File.Exists(filename))
        {
            Console.WriteLine($"Error: Config file not found: {filename}");
            Console.WriteLine("Current directory: " + Environment.CurrentDirectory);
            s_config = JsonDocument.Parse("{}");
            return;
        }

        try
        {
            var jsonText = File.ReadAllText(filename);
            s_config = JsonDocument.Parse(jsonText);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error parsing JSON config: {ex.Message}");
            s_config = JsonDocument.Parse("{}");
        }
    }
}