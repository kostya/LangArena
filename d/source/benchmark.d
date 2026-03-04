module benchmark;

import std.json;
import std.file;
import std.conv;
import std.datetime;
import std.algorithm;
import std.exception;
import std.stdio;
import std.string;
import helper;

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

        auto config = Helper.config;

        if (config.type == JSONType.object)
        {
            if (benchName in config.object)
            {
                auto benchObj = config[benchName];
                if (benchObj.type == JSONType.object)
                {
                    if ("warmup_iterations" in benchObj.object)
                    {
                        auto warmupField = benchObj["warmup_iterations"];

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
            }
        }

        int iters = iterations();
        return max(cast(int)(iters * 0.2), 1);
    }

private:
    T getConfigValue(T)(string className, string fieldName) const
    {
        auto config = Helper.config;

        if (config.type == JSONType.object)
        {
            if (className in config.object)
            {
                auto classObj = config[className];
                if (classObj.type == JSONType.object)
                {
                    if (fieldName in classObj.object)
                    {
                        auto value = classObj[fieldName];

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
                    }
                }
            }
        }
        throw new Exception("Config not found for " ~ className ~ ", field: " ~ fieldName);
    }
}
