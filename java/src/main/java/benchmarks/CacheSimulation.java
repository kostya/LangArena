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
            
            // Перемещаем узел в начало списка
            moveToFront(node);
            return node.value;
        }
        
        void put(K key, V value) {
            Node<K, V> existing = cache.get(key);
            if (existing != null) {
                // Обновляем существующий узел
                existing.value = value;
                moveToFront(existing);
                return;
            }
            
            // Удаляем самый старый если достигли capacity
            if (size >= capacity) {
                removeOldest();
            }
            
            // Создаем новый узел
            Node<K, V> node = new Node<>(key, value);
            
            // Добавляем в хеш-таблицу
            cache.put(key, node);
            
            // Добавляем в начало списка
            addToFront(node);
            
            size++;
        }
        
        int size() {
            return size;
        }
        
        private void moveToFront(Node<K, V> node) {
            // Если уже в начале, ничего не делаем
            if (node == head) return;
            
            // Удаляем из текущей позиции
            if (node.prev != null) {
                node.prev.next = node.next;
            }
            if (node.next != null) {
                node.next.prev = node.prev;
            }
            
            // Обновляем tail если нужно
            if (node == tail) {
                tail = node.prev;
            }
            
            // Вставляем в начало
            node.prev = null;
            node.next = head;
            if (head != null) {
                head.prev = node;
            }
            head = node;
            
            // Если список был пустой, обновляем tail
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
            
            // Удаляем из хеш-таблицы
            cache.remove(oldest.key);
            
            // Удаляем из списка
            if (oldest.prev != null) {
                oldest.prev.next = null;
            }
            tail = oldest.prev;
            
            // Обновляем head если нужно
            if (head == oldest) {
                head = null;
            }
            
            size--;
        }
    }
    
    private int operations;
    private long result;
    
    public CacheSimulation() {
        operations = getIterations() * 1000;
    }
    
    @Override
    public void run() {
        LRUCache<String, String> cache = new LRUCache<>(1000);
        int hits = 0;
        int misses = 0;
        
        for (int i = 0; i < operations; i++) {
            String key = "item_" + Helper.nextInt(2000);
            if (cache.get(key) != null) {
                hits++;
                cache.put(key, "updated_" + i);
            } else {
                misses++;
                cache.put(key, "new_" + i);
            }
        }
        
        String message = String.format("hits:%d|misses:%d|size:%d", 
            hits, misses, cache.size());
        result = Helper.checksum(message);
    }
    
    @Override
    public long getResult() {
        return result;
    }
}