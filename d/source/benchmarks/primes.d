module benchmarks.primes;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.math;
import std.range;
import benchmark;
import helper;

class Primes : Benchmark {
private:
    static struct Node {
        Node*[10] children;
        bool isTerminal;

        static this() {

        }
    }

    static int[] generatePrimes(int limit) {
        if (limit < 2) return [];

        bool[] isPrime = new bool[](limit + 1);
        isPrime[] = true;
        isPrime[0] = false;
        isPrime[1] = false;

        int sqrtLimit = cast(int)sqrt(cast(double)limit);

        for (int p = 2; p <= sqrtLimit; ++p) {
            if (isPrime[p]) {
                for (int multiple = p * p; multiple <= limit; multiple += p) {
                    isPrime[multiple] = false;
                }
            }
        }

        auto primes = appender!(int[]);
        foreach (i; 2 .. limit + 1) {
            if (isPrime[i]) {
                primes.put(i);
            }
        }

        return primes.data;
    }

    static Node* buildTrie(int[] primes) {
        Node* root = new Node();
        root.isTerminal = false;

        foreach (prime; primes) {
            Node* current = root;
            string digits = prime.to!string;

            foreach (digitChar; digits) {
                int digit = digitChar - '0';

                if (current.children[digit] is null) {
                    current.children[digit] = new Node();
                    current.children[digit].isTerminal = false;
                }
                current = current.children[digit];
            }
            current.isTerminal = true;
        }

        return root;
    }

    static int[] findPrimesWithPrefix(Node* trieRoot, int prefix) {
        string prefixStr = prefix.to!string;

        Node* current = trieRoot;
        foreach (digitChar; prefixStr) {
            int digit = digitChar - '0';

            if (current.children[digit] is null) {
                return [];
            }
            current = current.children[digit];
        }

        struct QueueItem {
            Node* node;
            int number;
        }

        int[] results;
        QueueItem[] queue;
        queue ~= QueueItem(current, prefix);

        while (!queue.empty) {
            auto item = queue.front;
            queue = queue[1..$];

            if (item.node.isTerminal) {
                results ~= item.number;
            }

            foreach (digit; 0 .. 10) {
                if (item.node.children[digit] !is null) {
                    queue ~= QueueItem(item.node.children[digit], 
                                     item.number * 10 + digit);
                }
            }
        }

        sort(results);
        return results;
    }

protected:
    int n;
    int prefix;
    uint resultVal;

    override string className() const { return "Primes"; }

public:
    this() {
        n = configVal("limit");
        prefix = configVal("prefix");
        resultVal = 5432;
    }

    override void run(int iterationId) {
        auto primes = generatePrimes(n);
        auto trie = buildTrie(primes);
        auto results = findPrimesWithPrefix(trie, prefix);

        resultVal += cast(uint)results.length;
        foreach (prime; results) {
            resultVal += cast(uint)prime;
        }
    }

    override uint checksum() {
        return resultVal;
    }
}