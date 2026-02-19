package benchmarks;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;

public class JsonParseDom extends Benchmark {
    private String text;
    private long resultVal;

    @Override
    public String name() {
        return "JsonParseDom";
    }

    @Override
    public void prepare() {
        JsonGenerate generator = new JsonGenerate();
        generator.n = (int) configVal("coords");
        generator.prepare();
        generator.run(0);
        text = generator.getText();
    }

    private double[] calc(String text) {
        JSONObject json = JSONObject.parseObject(text);
        JSONArray coordinates = json.getJSONArray("coordinates");

        double x = 0.0, y = 0.0, z = 0.0;

        for (int i = 0; i < coordinates.size(); i++) {
            JSONObject coord = coordinates.getJSONObject(i);
            x += coord.getDoubleValue("x");
            y += coord.getDoubleValue("y");
            z += coord.getDoubleValue("z");
        }

        double len = coordinates.size();
        return new double[] {x / len, y / len, z / len};
    }

    @Override
    public void run(int iterationId) {
        double[] values = calc(text);
        resultVal += ((int)Helper.checksumF64(values[0]) + (int)Helper.checksumF64(values[1]) + (int)Helper.checksumF64(values[2])) & 0xFFFFFFFFL;
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}