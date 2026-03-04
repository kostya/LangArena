package benchmarks;

import com.opencsv.CSVReader;
import com.opencsv.exceptions.CsvException;
import java.io.StringReader;
import java.io.IOException;
import java.util.List;
import java.util.ArrayList;
import java.util.Locale;

public class CsvParse extends Benchmark {
    private int rows;
    private String data;
    private long resultVal;

    public CsvParse() {
        this.rows = (int) configVal("rows");
        this.resultVal = 0;
        this.data = "";
    }

    @Override
    public String name() {
        return "CSV::Parse";
    }

    @Override
    public void prepare() {
        StringBuilder sb = new StringBuilder(rows * 50);

        for (int i = 0; i < rows; i++) {
            char c = (char) ('A' + (i % 26));
            double x = Helper.nextFloat();
            double z = Helper.nextFloat();
            double y = Helper.nextFloat();

            sb.append('"')
            .append("point ").append(c)
            .append("\\n, \"\"")
            .append(i % 100)
            .append("\"\"\"")
            .append(',');

            sb.append(String.format(Locale.US, "%.10f", x)).append(',');
            sb.append(',');
            sb.append(String.format(Locale.US, "%.10f", z)).append(',');

            sb.append('"')
            .append('[')
            .append(i % 2 == 0 ? "true" : "false")
            .append("\\n, ")
            .append(i % 100)
            .append(']')
            .append('"')
            .append(',');

            sb.append(String.format(Locale.US, "%.10f", y)).append('\n');
        }

        data = sb.toString();
    }

    private Point[] parsePoints(String csvData) {
        List<Point> points = new ArrayList<>();

        try (CSVReader reader = new CSVReader(new StringReader(csvData))) {
            String[] record;
            while ((record = reader.readNext()) != null) {
                double x = Double.parseDouble(record[1]);
                double z = Double.parseDouble(record[3]);
                double y = Double.parseDouble(record[5]);

                points.add(new Point(x, y, z));
            }
        } catch (IOException | CsvException e) {
            e.printStackTrace();
        }

        return points.toArray(new Point[0]);
    }

    @Override
    public void run(int iterationId) {
        Point[] points = parsePoints(data);

        if (points.length == 0) return;

        double xSum = 0.0, ySum = 0.0, zSum = 0.0;
        for (Point p : points) {
            xSum += p.x;
            ySum += p.y;
            zSum += p.z;
        }

        double len = points.length;
        double xAvg = xSum / len;
        double yAvg = ySum / len;
        double zAvg = zSum / len;

        resultVal += Helper.checksumF64(xAvg) + Helper.checksumF64(yAvg) + Helper.checksumF64(zAvg);
    }

    @Override
    public long checksum() {
        return resultVal;
    }

    private static class Point {
        double x, y, z;

        Point(double x, double y, double z) {
            this.x = x;
            this.y = y;
            this.z = z;
        }
    }
}