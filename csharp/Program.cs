using System.Numerics;

public class Program
{
    public static void Main(string[] args)
    {

        string configFile;

        if (args.Length > 0)
        {

            configFile = args[0];
        }
        else
        {

            var exeDir = Path.GetDirectoryName(Environment.ProcessPath) ?? ".";
            configFile = Path.Combine(exeDir, "../test.js");

            if (!File.Exists(configFile))
            {
                configFile = "test.js";
            }
        }

        if (!File.Exists(configFile))
        {
            Console.WriteLine($"Error: Config file not found: {configFile}");
            Console.WriteLine("Usage: Benchmark <config-file> [benchmark-name]");
            Environment.Exit(1);
        }

        Helper.LoadConfig(configFile);

        string? singleBench = args.Length > 1 ? args[1] : null;

        Benchmark.All(singleBench);
    }
}