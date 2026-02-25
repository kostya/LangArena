module benchmarks.cachesimulation;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.string;
import std.typecons;
import benchmark;
import helper;
import core.stdc.stdio : snprintf;

class CacheSimulation : Benchmark
{
private:

    class FastLRUCache
    {
    private:
        static struct Node
        {
            string key;
            string value;
            Node* prev;
            Node* next;
        }

        size_t capacity;
        Node*[string] nodeMap;
        Node* head = null;
        Node* tail = null;

        void detach(Node* node)
        {

            if (node.prev)
                node.prev.next = node.next;
            else
                head = node.next;

            if (node.next)
                node.next.prev = node.prev;
            else
                tail = node.prev;

            node.prev = null;
            node.next = null;
        }

        void attachToFront(Node* node)
        {
            node.next = head;
            node.prev = null;

            if (head)
                head.prev = node;
            head = node;

            if (tail is null)
                tail = node;
        }

        void removeOldest()
        {
            if (tail is null)
                return;

            auto oldNode = tail;
            nodeMap.remove(oldNode.key);

            tail = oldNode.prev;
            if (tail)
                tail.next = null;
            else
                head = null;
        }

    public:
        this(size_t capacity)
        {
            this.capacity = capacity;
        }

        bool get(string key)
        {
            if (auto pNode = key in nodeMap)
            {
                auto node = *pNode;

                if (node != head)
                {
                    detach(node);
                    attachToFront(node);
                }
                return true;
            }
            return false;
        }

        void put(string key, string value)
        {
            Node* node;

            if (auto pNode = key in nodeMap)
            {

                node = *pNode;
                node.value = value;

                if (node != head)
                {
                    detach(node);
                    attachToFront(node);
                }
                return;
            }

            if (nodeMap.length >= capacity && capacity > 0)
            {
                removeOldest();
            }

            node = new Node;
            node.key = key;
            node.value = value;

            nodeMap[key] = node;
            attachToFront(node);
        }

        size_t length() const
        {
            return nodeMap.length;
        }
    }

    uint resultVal;
    int valuesSize;
    int cacheSize;
    FastLRUCache cache;
    int hits = 0;
    int misses = 0;

protected:
    override string className() const
    {
        return "Etc::CacheSimulation";
    }

public:
    this()
    {
        resultVal = 5432;
        valuesSize = configVal("values");
        cacheSize = configVal("size");
        cache = new FastLRUCache(1);
    }

    override void prepare()
    {
        cache = new FastLRUCache(cacheSize > 0 ? cacheSize : 1);
        hits = 0;
        misses = 0;
    }

    override void run(int iterationId)
    {
        for (int n = 0; n < 1000; n++)
        {
            char[32] keyBuf;
            int keyNum = Helper.nextInt(valuesSize);
            auto keyLen = snprintf(keyBuf.ptr, keyBuf.length, "item_%d", keyNum);
            string key = keyBuf[0 .. keyLen].idup;

            if (cache.get(key))
            {
                hits++;
                char[32] valBuf;
                auto valLen = snprintf(valBuf.ptr, valBuf.length, "updated_%d", iterationId);
                string value = valBuf[0 .. valLen].idup;
                cache.put(key, value);
            }
            else
            {
                misses++;
                char[32] valBuf;
                auto valLen = snprintf(valBuf.ptr, valBuf.length, "new_%d", iterationId);
                string value = valBuf[0 .. valLen].idup;
                cache.put(key, value);
            }
        }
    }

    override uint checksum()
    {
        uint finalResult = resultVal;
        finalResult = (finalResult << 5) + hits;
        finalResult = (finalResult << 5) + misses;
        finalResult = (finalResult << 5) + cast(uint) cache.length();
        return finalResult;
    }
}
