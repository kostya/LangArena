package benchmarks;

import com.alibaba.fastjson2.JSONArray;
import com.alibaba.fastjson2.JSONObject;
import java.util.*;

public class JsonGenerate extends Benchmark {
    public int n;
    private List<Map<String, Object>> data;
    private String text;
    private long resultVal;

    public JsonGenerate() {
        n = (int) configVal("coords");
        data = new ArrayList<>(n);
        text = "";
        resultVal = 0;
    }

    @Override
    public String name() {
        return "Json::Generate";
    }

    @Override
    public void prepare() {
        for (int i = 0; i < n; i++) {
            Map<String, Object> coord = new LinkedHashMap<>();

            coord.put("x", Math.round(Helper.nextFloat() * 1e8) / 1e8);
            coord.put("y", Math.round(Helper.nextFloat() * 1e8) / 1e8);
            coord.put("z", Math.round(Helper.nextFloat() * 1e8) / 1e8);

            coord.put("name", String.format(Locale.US, "%.7f %d",
                                            Helper.nextFloat(), Helper.nextInt(10000)));

            Map<String, List<Object>> opts = new LinkedHashMap<>();
            List<Object> tuple = new ArrayList<>();
            tuple.add(1);
            tuple.add(true);
            opts.put("1", tuple);
            coord.put("opts", opts);

            data.add(coord);
        }
    }

    @Override
    public void run(int iterationId) {
        JSONArray jsonArray = new JSONArray();
        for (Map<String, Object> coord : data) {
            jsonArray.add(coord);
        }

        JSONObject jsonObject = new JSONObject();
        jsonObject.put("coordinates", jsonArray);
        jsonObject.put("info", "some info");

        text = jsonObject.toString();
        if (text.startsWith("{\"coordinates\":")) resultVal += 1;
    }

    @Override
    public long checksum() {
        return resultVal;
    }

    public String getText() {
        return text;
    }
}