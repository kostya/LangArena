using System.Text;

public static class Helper
{
    private const long IM = 139968;
    private const long IA = 3877;
    private const long IC = 29573;
    private const int INIT = 42;
    
    private static long s_last = INIT;
    
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
        // Debug($"checksum: {v}");
        uint hash = 5381;
        foreach (byte b in Encoding.UTF8.GetBytes(v))
        {
            hash = ((hash << 5) + hash) + b;
        }
        return hash;
    }
   
    public static uint Checksum(byte[] bytes)
    {
        // Debug($"checksum: {BitConverter.ToString(bytes)}");
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
    
    private static void Debug(string message)
    {
        // В C# нет директив компиляции как в Crystal, используем переменную окружения
        if (Environment.GetEnvironmentVariable("DEBUG") == "1")
        {
#if DEBUG
            Console.WriteLine($"DEBUG: {message}");
#else
            // В релизе тоже можно выводить, если DEBUG=1
            Console.WriteLine($"DEBUG: {message}");
#endif
        }
    }
    
    // Конфигурация
    public static Dictionary<string, string> Input = new();
    public static Dictionary<string, long> Expect = new();
    
	public static void LoadConfig(string? filename = null)
	{
	    filename ??= "test.txt";
	    
	    // Console.WriteLine($"Trying to load config: {filename}");
	    // Console.WriteLine($"File exists: {File.Exists(filename)}");
	    
	    if (!File.Exists(filename))
	    {
	        // Пробуем альтернативные пути
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
	        return;
	    }
	    
	    Input.Clear();
	    Expect.Clear();
	    
	    var lines = File.ReadAllLines(filename)
	        .Where(l => !string.IsNullOrWhiteSpace(l));
	    
	    foreach (var line in lines)
	    {
	        var parts = line.Split('|');
	        if (parts.Length >= 3)
	        {
	            Input[parts[0]] = parts[1];
	            Expect[parts[0]] = long.Parse(parts[2]);
	        }
	    }
	}
}