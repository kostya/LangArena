package benchmarks;

import java.util.*;

public class CacheSimulation extends Benchmark {

    static class LRUCache<K, V> {
        static class Node<K, V> {
            K key;
            V value;
            Node<K, V> prev;
            Node<K, V> next;

            Node(K key, V value) {
                this.key = key;
                this.value = value;
            }
        }

        private final int capacity;
        private final Map<K, Node<K, V>> cache;
        private Node<K, V> head;
        private Node<K, V> tail;
        private int size;

        LRUCache(int capacity) {
            this.capacity = capacity;
            this.cache = new HashMap<>();
        }

        V get(K key) {
            Node<K, V> node = cache.get(key);
            if (node == null) return null;

            moveToFront(node);
            return node.value;
        }

        void put(K key, V value) {
            Node<K, V> existing = cache.get(key);
            if (existing != null) {

                existing.value = value;
                moveToFront(existing);
                return;
            }

            if (size >= capacity) {
                removeOldest();
            }

            Node<K, V> node = new Node<>(key, value);

            cache.put(key, node);

            addToFront(node);

            size++;
        }

        int size() {
            return size;
        }

        private void moveToFront(Node<K, V> node) {

            if (node == head) return;

            if (node.prev != null) {
                node.prev.next = node.next;
            }
            if (node.next != null) {
                node.next.prev = node.prev;
            }

            if (node == tail) {
                tail = node.prev;
            }

            node.prev = null;
            node.next = head;
            if (head != null) {
                head.prev = node;
            }
            head = node;

            if (tail == null) {
                tail = node;
            }
        }

        private void addToFront(Node<K, V> node) {
            node.next = head;
            if (head != null) {
                head.prev = node;
            }
            head = node;
            if (tail == null) {
                tail = node;
            }
        }

        private void removeOldest() {
            if (tail == null) return;

            Node<K, V> oldest = tail;

            cache.remove(oldest.key);

            if (oldest.prev != null) {
                oldest.prev.next = null;
            }
            tail = oldest.prev;

            if (head == oldest) {
                head = null;
            }

            size--;
        }
    }

    private long resultVal;
    private final int valuesSize;
    private final int cacheSize;
    private LRUCache<String, String> cache;
    private int hits = 0;
    private int misses = 0;

    public CacheSimulation() {
        this.resultVal = 5432L;
        this.valuesSize = (int) configVal("values");
        this.cacheSize = (int) configVal("size");
    }

    @Override
    public String name() {
        return "Etc::CacheSimulation";
    }

    @Override
    public void prepare() {
        cache = new LRUCache<>(cacheSize);
    }

    @Override
    public void run(int iterationId) {
        for (int n = 0; n < 1000; n++) {
            String key = "item_" + Helper.nextInt(valuesSize);
            if (cache.get(key) != null) {
                hits++;
                cache.put(key, "updated_" + iterationId);
            } else {
                misses++;
                cache.put(key, "new_" + iterationId);
            }
        }
    }

    @Override
    public long checksum() {
        long finalResult = resultVal;
        finalResult = (finalResult << 5) + hits;
        finalResult = (finalResult << 5) + misses;
        finalResult = (finalResult << 5) + cache.size();
        return finalResult;
    }
}