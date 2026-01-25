package benchmarks;

import org.json.JSONArray;
import org.json.JSONObject;
import java.util.*;

public class JsonParseMapping extends Benchmark {
    
    static class Coord {
        double x, y, z;
        
        Coord(double x, double y, double z) {
            this.x = x;
            this.y = y;
            this.z = z;
        }
    }
    
    static class Coordinates {
        List<Coord> coordinates = new ArrayList<>();
    }
    
    private String text;
    private long result;
    
    @Override
    public void prepare() {
        JsonGenerate generator = new JsonGenerate();
        generator.n = getIterations();
        generator.prepare();
        generator.run();
        
        // Получаем данные из генератора
        try {
            var dataField = JsonGenerate.class.getDeclaredField("data");
            dataField.setAccessible(true);
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> data = (List<Map<String, Object>>) dataField.get(generator);
            
            // Конвертируем в JSON
            JSONArray jsonArray = new JSONArray();
            for (Map<String, Object> coord : data) {
                JSONObject obj = new JSONObject();
                obj.put("x", Double.parseDouble(coord.get("x").toString()));
                obj.put("y", Double.parseDouble(coord.get("y").toString()));
                obj.put("z", Double.parseDouble(coord.get("z").toString()));
                jsonArray.put(obj);
            }
            
            JSONObject jsonObject = new JSONObject();
            jsonObject.put("coordinates", jsonArray);
            text = jsonObject.toString();
            
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
    
    private Coord calc(String text) {
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
        return new Coord(x / len, y / len, z / len);
    }
    
    @Override
    public void run() {
        Coord coord = calc(text);
        result = ((int)Helper.checksumF64(coord.x) + (int)Helper.checksumF64(coord.y) + (int)Helper.checksumF64(coord.z)) & 0xFFFFFFFFL;
    }
    
    @Override
    public long getResult() {
        return result;
    }
}