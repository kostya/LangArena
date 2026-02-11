(ns benchmarks.brainfuck-array
  (:require [benchmarks.core :refer [bench config-s]])
  (:import [java.util ArrayDeque]))

(defn compile-program [text]
  (let [bytes (->> text
                   (filter #(contains? #{\[ \] \< \> \+ \- \.} %))
                   (map byte)
                   (byte-array))
        n (alength bytes)
        jumps (int-array n)
        stack (ArrayDeque.)]
    (dotimes [i n]
      (let [b (aget bytes i)]
        (when (= b (byte \[)) (.push stack i))
        (when (= b (byte \]))
          (let [start (.pop stack)]
            (aset jumps start i)
            (aset jumps i start)))))
    [bytes jumps n]))

(defn run-program [commands jumps n]
  (let [tape (byte-array 30000)
        commands ^bytes commands  
        jumps ^ints jumps
        n ^int n]
    (loop [pc 0
           pos 0
           result 0]
      (if (>= pc n)
        result
        (let [cmd (aget commands pc)]
          (cond
            (= cmd 43)  
            (do (aset tape pos (byte (inc (aget tape pos))))
                (recur (inc pc) pos result))

            (= cmd 45)  
            (do (aset tape pos (byte (dec (aget tape pos))))
                (recur (inc pc) pos result))

            (= cmd 62)  
            (let [new-pos (inc pos)]
              (if (< new-pos (alength tape))
                (recur (inc pc) new-pos result)
                (recur (inc pc) pos result)))  

            (= cmd 60)  
            (recur (inc pc) (max 0 (dec pos)) result)

            (= cmd 91)  
            (if (zero? (aget tape pos))
              (recur (inc (aget jumps pc)) pos result)
              (recur (inc pc) pos result))

            (= cmd 93)  
            (if (not (zero? (aget tape pos)))
              (recur (aget jumps pc) pos result)
              (recur (inc pc) pos result))

            (= cmd 46)  
            (let [b (bit-and (aget tape pos) 0xFF)]
              (recur (inc pc) pos 
                     (+ (bit-shift-left result 2) b)))

            :else
            (recur (inc pc) pos result)))))))

(bench "BrainfuckArray"
  (let [program (atom nil)
        warmup-program (atom nil)
        result (atom 0)])

  (init
    (let [[c j n] (compile-program (config-s "BrainfuckArray" "program"))
          [wc wj wn] (compile-program (config-s "BrainfuckArray" "warmup_program"))]
      (reset! program [c j n])
      (reset! warmup-program [wc wj wn])))

  (warmup [this]
    (let [[c j n] @warmup-program
          warmup-iters (.warmupIterations this)]
      (dotimes [_ warmup-iters]
        (run-program c j n))))

  (run [_]
    (let [[c j n] @program]
      (swap! result + (run-program c j n))))

  (checksum
    (bit-and @result 0xFFFFFFFF)))