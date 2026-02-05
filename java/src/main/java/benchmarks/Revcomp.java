package benchmarks;

public class Revcomp extends Benchmark {
    private String input;
    private long resultVal;
    private static final char[] LOOKUP = new char[256];

    static {

        for (int i = 0; i < 256; i++) {
            LOOKUP[i] = (char)i;
        }

        String from = "wsatugcyrkmbdhvnATUGCYRKMBDHVN";
        String to   = "WSTAACGRYMKVHDBNTAACGRYMKVHDBN";

        for (int i = 0; i < from.length(); i++) {
            LOOKUP[from.charAt(i)] = to.charAt(i);
        }
    }

    public Revcomp() {
        resultVal = 0L;
    }

    @Override
    public String name() {
        return "Revcomp";
    }

    @Override
    public void prepare() {
        Fasta fasta = new Fasta();
        fasta.n = (int) configVal("n");
        fasta.run(0);

        String fastaResult = fasta.getResultString();

        StringBuilder seq = new StringBuilder();
        int start = 0;
        int end;

        while ((end = fastaResult.indexOf('\n', start)) != -1) {
            String line = fastaResult.substring(start, end);

            if (line.startsWith(">")) {
                seq.append("\n---\n");
            } else {
                seq.append(line);
            }

            start = end + 1;
        }

        input = seq.toString();
    }

    @Override
    public void run(int iterationId) {
        resultVal += Helper.checksum(revcompString(input));
    }

    private String revcompString(String seq) {
        int length = seq.length();
        int lines = (length + 59) / 60;
        char[] result = new char[length + lines];
        int pos = 0;

        for (int start = length; start > 0; start -= 60) {
            int chunkStart = Math.max(start - 60, 0);
            int chunkSize = start - chunkStart;

            for (int i = start - 1; i >= chunkStart; i--) {
                char c = seq.charAt(i);
                result[pos++] = LOOKUP[c];
            }

            result[pos++] = '\n';
        }

        if (length % 60 == 0 && length > 0) {
            pos--;
        }

        return new String(result, 0, pos);
    }

    @Override
    public long checksum() {
        return resultVal;
    }
}