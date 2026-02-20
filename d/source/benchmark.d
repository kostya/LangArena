module benchmark;

import std.json;
import std.file;
import std.conv;
import std.datetime;
import std.algorithm;
import std.exception;
import std.stdio;
import std.string;

__gshared JSONValue config;

void loadConfig(string filename = "../test.js")
{
    try
    {
        string content = readText(filename);
        config = parseJSON(content);
    }
    catch (Exception e)
    {
        stderr.writeln("Cannot open config file: ", filename);
        config = JSONValue(null);
    }
}

abstract class Benchmark
{
protected:
    double timeDelta = 0.0;

    protected abstract string className() const;

public:

    final string name() const
    {
        return className();
    }

    abstract void run(int iterationId);
    abstract uint checksum();

    void prepare()
    {
    }

    void warmup()
    {
        int prepareIters = warmupIterations();
        foreach (i; 0 .. prepareIters)
        {
            this.run(i);
        }
    }

    void runAll()
    {
        int iters = iterations();
        foreach (i; 0 .. iters)
        {
            this.run(i);
        }
    }

    void setTimeDelta(double delta)
    {
        timeDelta = delta;
    }

    int iterations() const
    {
        return configVal("iterations");
    }

    uint expectedChecksum() const
    {
        return uint(configVal("checksum"));
    }

protected:

    int configVal(string fieldName) const
    {
        return getConfigValue!int(this.name, fieldName);
    }

    string configStr(string fieldName) const
    {
        return getConfigValue!string(this.name, fieldName);
    }

protected:
    int warmupIterations()
    {

        string benchName = name();

        if (config.type == JSONType.object && config[benchName] != JSONValue(null)
                && config[benchName].type == JSONType.object)
        {

            if (fieldExists(config[benchName], "warmup_iterations"))
            {

                auto warmupField = config[benchName]["warmup_iterations"];

                if (warmupField.type == JSONType.integer)
                {
                    return warmupField.integer.to!int;
                }
                else if (warmupField.type == JSONType.uinteger)
                {
                    return warmupField.uinteger.to!int;
                }
                else if (warmupField.type == JSONType.string)
                {
                    return warmupField.str.to!int;
                }
                else if (warmupField.type == JSONType.float_)
                {
                    return cast(int) warmupField.floating;
                }

            }
        }

        int iters = iterations();
        return max(cast(int)(iters * 0.2), 1);
    }

private:
    bool fieldExists(JSONValue obj, string fieldName) const
    {
        if (obj.type != JSONType.object)
            return false;
        foreach (key, value; obj.object)
        {
            if (key == fieldName)
                return true;
        }
        return false;
    }

    T getConfigValue(T)(string className, string fieldName) const
    {
        if (config.type == JSONType.object && fieldExists(config, className)
                && config[className].type == JSONType.object
                && fieldExists(config[className], fieldName))
        {

            auto value = config[className][fieldName];

            static if (is(T == int) || is(T == long))
            {
                if (value.type == JSONType.integer)
                {
                    return cast(T) value.integer;
                }
                else if (value.type == JSONType.uinteger)
                {
                    return cast(T) value.uinteger;
                }
                else if (value.type == JSONType.string)
                {
                    return value.str.to!T;
                }
                else if (value.type == JSONType.float_)
                {
                    return cast(T) value.floating;
                }
            }
            else static if (is(T == string))
            {
                if (value.type == JSONType.string)
                {
                    return value.str;
                }
                else
                {
                    return value.to!string;
                }
            }

            throw new Exception("Cannot convert JSON value");
        }
        throw new Exception("Config not found for " ~ className ~ ", field: " ~ fieldName);
    }
}
