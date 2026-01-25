package benchmarks;

import org.json.JSONArray;
import org.json.JSONObject;
import java.util.*;

public class JsonGenerate extends Benchmark {
    public int n;
    private List<Map<String, Object>> data;
    private String text;
    
    public JsonGenerate() {
        n = getIterations();
    }
    
    @Override
    public void prepare() {
        data = new ArrayList<>(n);
        
        for (int i = 0; i < n; i++) {
            Map<String, Object> coord = new HashMap<>();
            
            // Форматирование как в Crystal версии
            coord.put("x", String.format(Locale.US, "%.8f", Helper.nextFloat()));
            coord.put("y", String.format(Locale.US, "%.8f", Helper.nextFloat()));
            coord.put("z", String.format(Locale.US, "%.8f", Helper.nextFloat()));
            coord.put("name", String.format(Locale.US, "%.7f", Helper.nextFloat()) + 
                              " " + Helper.nextInt(10000));
            coord.put("opts", Collections.singletonMap("1", Arrays.asList(1, true)));
            
            data.add(coord);
        }
    }
    
    @Override
    public void run() {
        JSONArray jsonArray = new JSONArray();
        for (Map<String, Object> coord : data) {
            jsonArray.put(coord);
        }
        
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("coordinates", jsonArray);
        jsonObject.put("info", "some info");
        
        text = jsonObject.toString();
    }
    
    // Как в Crystal версии: всегда возвращает 1
    @Override
    public long getResult() {
        return 1L;
    }
}