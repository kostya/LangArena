using System.Numerics; // для Pidigits

public class Program
{
    public static void Main(string[] args)
    {
        // Определяем путь к конфигу
        string configFile;
        
        if (args.Length > 0)
        {
            // Если путь указан явно
            configFile = args[0];
        }
        else
        {
            // Пытаемся найти конфиг относительно исполняемого файла
            var exeDir = Path.GetDirectoryName(Environment.ProcessPath) ?? ".";
            configFile = Path.Combine(exeDir, "../test.txt");
            
            // Если не нашли, пробуем относительно текущей директории
            if (!File.Exists(configFile))
            {
                configFile = "test.txt";
            }
        }
        
        if (!File.Exists(configFile))
        {
            Console.WriteLine($"Error: Config file not found: {configFile}");
            Console.WriteLine("Usage: Benchmark <config-file> [benchmark-name]");
            Environment.Exit(1);
        }
        
        Helper.LoadConfig(configFile);
        
        // Определяем, запускать ли конкретный бенчмарк
        string? singleBench = args.Length > 1 ? args[1] : null;
        
        // Запускаем бенчмарки
        Benchmark.RunBenchmarks(singleBench);
    }
}