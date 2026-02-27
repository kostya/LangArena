package benchmarks;

import java.util.*;

public class Words extends Benchmark {
    private int words;
    private int wordLen;
    private String text;
    private long checksumVal;

    public Words() {
        words = (int) configVal("words");
        wordLen = (int) configVal("word_len");
        checksumVal = 0;
    }

    @Override
    public String name() {
        return "Etc::Words";
    }

    @Override
    public void prepare() {
        char[] chars = "abcdefghijklmnopqrstuvwxyz".toCharArray();
        List<String> wordsList = new ArrayList<>(words);

        for (int i = 0; i < words; i++) {
            int len = Helper.nextInt(wordLen) + Helper.nextInt(3) + 3;
            char[] wordChars = new char[len];
            for (int j = 0; j < len; j++) {
                wordChars[j] = chars[Helper.nextInt(chars.length)];
            }
            wordsList.add(new String(wordChars));
        }

        text = String.join(" ", wordsList);
    }

    @Override
    public void run(int iterationId) {

        Map<String, Integer> frequencies = new HashMap<>();

        for (String word : text.split(" ")) {
            if (word.isEmpty()) continue;
            frequencies.put(word, frequencies.getOrDefault(word, 0) + 1);
        }

        String maxWord = "";
        int maxCount = 0;

        for (Map.Entry<String, Integer> entry : frequencies.entrySet()) {
            if (entry.getValue() > maxCount) {
                maxCount = entry.getValue();
                maxWord = entry.getKey();
            }
        }

        checksumVal += maxCount + Helper.checksum(maxWord) + frequencies.size();
    }

    @Override
    public long checksum() {
        return checksumVal;
    }
}