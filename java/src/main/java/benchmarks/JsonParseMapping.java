package benchmarks;

import com.alibaba.fastjson2.JSON;
import java.util.List;

public class JsonParseMapping extends Benchmark {

    public static class Coordinate {
        public double x;
        public double y;
        public double z;

        public Coordinate() {}
    }

    public static class CoordinatesData {
        public List<Coordinate> coordinates;
    }

    private String text;
    private long resultVal = 0;

    @Override
    public void prepare() {
        JsonGenerate generator = new JsonGenerate();
        generator.n = (int) configVal("coords");
        generator.prepare();
        generator.run(0);
        text = generator.getText();
    }

    private double[] calc(String text) {
        CoordinatesData data = JSON.parseObject(text, CoordinatesData.class);
        List<Coordinate> coords = data.coordinates;

        double x = 0.0, y = 0.0, z = 0.0;
        int size = coords.size();

        for (int i = 0; i < size; i++) {
            Coordinate c = coords.get(i);
            x += c.x;
            y += c.y;
            z += c.z;
        }

        double len = size;
        return new double[]{x / len, y / len, z / len};
    }

    @Override
    public void run(int iterationId) {
        double[] result = calc(text);
        resultVal += ((int)Helper.checksumF64(result[0]) + (int)Helper.checksumF64(result[1]) + (int)Helper.checksumF64(result[2])) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return resultVal;
    }

    @Override
    public String name() {
        return "JsonParseMapping";
    }
}