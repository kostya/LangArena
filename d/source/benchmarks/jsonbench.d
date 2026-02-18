module benchmarks.jsonbench;

import benchmark;
import helper;
import std.stdio;
import std.conv;
import std.array;
import std.format;
import std.typecons;

import asdf;

struct OptEntry {
    int first;
    bool second;
}

struct Coordinate {
    double x;
    double y;
    double z;
    string name;
    OptEntry[string] opts;

    this(double x, double y, double z, string name) {
        this.x = x;
        this.y = y;
        this.z = z;
        this.name = name;
        this.opts = ["1": OptEntry(1, true)];
    }
}

struct CoordinateSimple {
    double x;
    double y;
    double z;

}

struct JsonRoot {
    CoordinateSimple[] coordinates;
    string info;
}

class JsonGenerate : Benchmark {
private:
    Coordinate[] data;
    string generatedJson;
    uint resultVal;

    double customRound(double val, int decimals) {
        import std.string : format;
        return format("%." ~ to!string(decimals) ~ "f", val).to!double;
    }

public:
    long n;

    this() {
        n = configVal("coords");
        resultVal = 0;
    }

    override string className() const { return "JsonGenerate"; }

    override void prepare() {
        data.length = cast(size_t)n;

        foreach (i; 0 .. n) {
            double x = customRound(Helper.nextFloat(), 8);
            double y = customRound(Helper.nextFloat(), 8);
            double z = customRound(Helper.nextFloat(), 8);

            string name = format("%.7f %s", Helper.nextFloat(), Helper.nextInt(10000));

            data[cast(size_t)i] = Coordinate(x, y, z, name);
        }
    }

    override void run(int iterationId) {
        struct RootForGenerate {
            Coordinate[] coordinates;
            string info;
        }

        RootForGenerate root;
        root.coordinates = data;
        root.info = "some info";

        generatedJson = serializeToJson(root);

        if (generatedJson.length >= 15 && generatedJson[0..15] == "{\"coordinates\":") {
            resultVal++;
        }
    }

    override uint checksum() {
        return resultVal;
    }

    string getJson() const {
        return generatedJson;
    }
}

class JsonParseDom : Benchmark {
private:
    string jsonText;
    uint resultVal;

public:
    this() {
        resultVal = 0;
    }

    override string className() const { return "JsonParseDom"; }

    override void prepare() {
        auto generator = new JsonGenerate();
        generator.n = configVal("coords");
        generator.prepare();
        generator.run(0);
        jsonText = generator.getJson();
    }

    override void run(int iterationId) {
        auto document = parseJson(jsonText);
        auto coords = document["coordinates"];

        double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
        size_t count = 0;

        if (coords.kind == Asdf.Kind.array) {
            foreach (coord; coords.byElement) {
                x_sum += coord["x"].get!double(0.0);
                y_sum += coord["y"].get!double(0.0);
                z_sum += coord["z"].get!double(0.0);
                count++;
            }
        }

        if (count > 0) {
            double x_avg = x_sum / count;
            double y_avg = y_sum / count;
            double z_avg = z_sum / count;

            resultVal += Helper.checksumF64(x_avg) +
                        Helper.checksumF64(y_avg) +
                        Helper.checksumF64(z_avg);
        }
    }

    override uint checksum() {
        return resultVal;
    }
}

class JsonParseMapping : Benchmark {
private:
    string jsonText;
    uint resultVal;

public:
    this() {
        resultVal = 0;
    }

    override string className() const { return "JsonParseMapping"; }

    override void prepare() {
        auto generator = new JsonGenerate();
        generator.n = configVal("coords");
        generator.prepare();
        generator.run(0);
        jsonText = generator.getJson();
    }

    override void run(int iterationId) {
        JsonRoot root = jsonText.deserialize!JsonRoot;

        double x_sum = 0.0, y_sum = 0.0, z_sum = 0.0;
        size_t count = root.coordinates.length;

        foreach (coord; root.coordinates) {
            x_sum += coord.x;
            y_sum += coord.y;
            z_sum += coord.z;
        }

        if (count > 0) {
            double x_avg = x_sum / count;
            double y_avg = y_sum / count;
            double z_avg = z_sum / count;

            resultVal += Helper.checksumF64(x_avg) +
                        Helper.checksumF64(y_avg) +
                        Helper.checksumF64(z_avg);
        }
    }

    override uint checksum() {
        return resultVal;
    }
}