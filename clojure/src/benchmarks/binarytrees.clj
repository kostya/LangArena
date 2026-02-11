(ns benchmarks.binarytrees
  (:require [benchmarks.core :refer [bench config-i64]]))

(defrecord TreeNode [item left right])

(defn check-tree [^TreeNode node]
  (if (nil? (:left node))
    (:item node)
    (- (+ (check-tree (:left node)) (:item node))
       (check-tree (:right node)))))

(defn create-tree [item depth]
  (if (> depth 0)
    (TreeNode. item
              (create-tree (- (* 2 item) 1) (dec depth))
              (create-tree (* 2 item) (dec depth)))
    (TreeNode. item nil nil)))

(bench "Binarytrees"
  (let [depth (atom 0)
        result (atom 0)])

  (init
  	(reset! depth (config-i64 "Binarytrees" "depth")))

  (run [iteration-id]
    (let [n @depth
          min-depth 4
          max-depth (max (+ min-depth 2) n)
          stretch-depth (+ max-depth 1)]

      (swap! result + (check-tree (create-tree 0 stretch-depth)))

      (doseq [d (range min-depth (inc max-depth) 2)]
        (let [iterations (bit-shift-left 1 (+ (- max-depth d) min-depth))]
          (dotimes [i iterations]
            (let [idx (inc i)]
              (swap! result + (check-tree (create-tree idx d)))
              (swap! result + (check-tree (create-tree (- idx) d)))))))))

  (checksum
  	 (bit-and @result 0xFFFFFFFF)))