package benchmarks;

import org.json.JSONArray;
import org.json.JSONObject;

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

        try {
            var textField = JsonGenerate.class.getDeclaredField("text");
            textField.setAccessible(true);
            text = (String) textField.get(generator);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private double[] calc(String text) {
        JSONObject json = new JSONObject(text);
        JSONArray coordinates = json.getJSONArray("coordinates");

        double x = 0.0, y = 0.0, z = 0.0;

        for (int i = 0; i < coordinates.length(); i++) {
            JSONObject coord = coordinates.getJSONObject(i);
            x += coord.getDouble("x");
            y += coord.getDouble("y");
            z += coord.getDouble("z");
        }

        double len = coordinates.length();
        return new double[]{x / len, y / len, z / len};
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