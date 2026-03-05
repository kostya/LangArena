using System.Globalization;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;

public class CsvParse : Benchmark
{
    private int _rows;
    private string _data = "";
    private uint _result;

    public CsvParse()
    {
        _result = 0;
        _rows = (int)ConfigVal("rows");
    }

    public override void Prepare()
    {
        var sb = new StringBuilder(_rows * 50);

        for (int i = 0; i < _rows; i++)
        {
            char c = (char)('A' + (i % 26));
            double x = Helper.NextFloat();
            double z = Helper.NextFloat();
            double y = Helper.NextFloat();
            sb.Append('"').Append("point ").Append(c).Append("\\n, \"\"").Append(i % 100).Append("\"\"\"").Append(',');
            sb.Append(x.ToString("F10", CultureInfo.InvariantCulture)).Append(',');
            sb.Append(',');
            sb.Append(z.ToString("F10", CultureInfo.InvariantCulture)).Append(',');
            sb.Append('"').Append('[').Append(i % 2 == 0 ? "true" : "false").Append("\\n, ").Append(i % 100).Append(']').Append('"').Append(',');
            sb.Append(y.ToString("F10", CultureInfo.InvariantCulture)).Append('\n');
        }

        _data = sb.ToString();
    }

    private record Point(double X, double Y, double Z);

    private List<Point> ParsePoints(string csvData)
    {
        using var reader = new StringReader(csvData);
        using var csv = new CsvReader(reader, new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = false,
            Mode = CsvMode.RFC4180
        });

        var records = new List<Point>();

        while (csv.Read())
        {
            var x = csv.GetField<double>(1);
            var z = csv.GetField<double>(3);
            var y = csv.GetField<double>(5);
            records.Add(new Point(x, y, z));
        }

        return records;
    }

    public override void Run(long iterationId)
    {
        var points = ParsePoints(_data);

        if (points.Count == 0) return;

        double xSum = 0, ySum = 0, zSum = 0;
        foreach (var p in points)
        {
            xSum += p.X;
            ySum += p.Y;
            zSum += p.Z;
        }

        double count = points.Count;
        double xAvg = xSum / count;
        double yAvg = ySum / count;
        double zAvg = zSum / count;

        _result += Helper.Checksum(xAvg) + Helper.Checksum(yAvg) + Helper.Checksum(zAvg);
    }

    public override uint Checksum => _result;
    public override string TypeName => "CSV::Parse";
}