(ns benchmarks.brainfuck-recursion
  (:require [benchmarks.core :refer [bench config-s]])
  (:import [java.util ArrayDeque]))

(defn make-tape []
  (byte-array 1))

(defn tape-get [tape pos]
  (aget tape pos))

(defn tape-inc! [tape pos x]
  (aset tape pos (byte (+ (aget tape pos) x))))

(defn tape-prev! [pos]
  (dec pos))

(defn tape-next! [tape pos]
  (let [new-pos (inc pos)]
    (if (>= new-pos (alength tape))
      (let [new-tape (byte-array (* new-pos 2))]
        (System/arraycopy tape 0 new-tape 0 (alength tape))
        [new-tape new-pos])
      [tape new-pos])))

(defprotocol Op
  (execute [this tape pos result]))

(deftype Dec []
  Op
  (execute [_ tape pos result]
    (tape-inc! tape pos -1)
    [tape pos result]))

(deftype Inc []
  Op
  (execute [_ tape pos result]
    (tape-inc! tape pos 1)
    [tape pos result]))

(deftype Prev []
  Op
  (execute [_ tape pos result]
    [tape (tape-prev! pos) result]))

(deftype Next []
  Op
  (execute [_ tape pos result]
    (let [[new-tape new-pos] (tape-next! tape pos)]
      [new-tape new-pos result])))

(deftype Print []
  Op
  (execute [_ tape pos result]
    (let [b (bit-and (tape-get tape pos) 0xFF)
          new-result (+ (bit-shift-left result 2) b)]
      [tape pos new-result])))

(deftype Loop [body]
  Op
  (execute [_ tape pos result]
    (loop [tape tape
           pos pos
           result result]
      (if (zero? (tape-get tape pos))
        [tape pos result]
        (let [[new-tape new-pos new-result] 
              (loop [ops body
                     t tape
                     p pos
                     r result]
                (if (empty? ops)
                  [t p r]
                  (let [[t2 p2 r2] (execute (first ops) t p r)]
                    (recur (rest ops) t2 p2 r2))))]
          (recur new-tape new-pos new-result))))))

(defn parse-program [code]
  (let [len (count code)
        idx (atom 0)]

    (letfn [(parse []
              (loop [ops []]
                (if (>= @idx len)
                  ops
                  (let [c (nth code @idx)]
                    (swap! idx inc)
                    (case c
                      \+ (recur (conj ops (->Inc)))
                      \- (recur (conj ops (->Dec)))
                      \< (recur (conj ops (->Prev)))
                      \> (recur (conj ops (->Next)))
                      \. (recur (conj ops (->Print)))
                      \[ (let [loop-ops (parse)]
                           (recur (conj ops (->Loop (vec loop-ops)))))
                      \] ops
                      (recur ops))))))]
      (parse))))

(defn run-program [program-ops]
  (loop [ops program-ops
         tape (make-tape)
         pos 0
         result 0]
    (if (empty? ops)
      result
      (let [[new-tape new-pos new-result] 
            (execute (first ops) tape pos result)]
        (recur (rest ops) new-tape new-pos new-result)))))

(bench "BrainfuckRecursion"
  (let [program (atom nil)
        warmup-program (atom nil)
        result (atom 0)])

  (init
    (reset! program (parse-program (config-s "BrainfuckRecursion" "program")))
    (reset! warmup-program (parse-program (config-s "BrainfuckRecursion" "warmup_program"))))

  (warmup [this]
    (let [prog @warmup-program
          warmup-iters (.warmupIterations this)]
      (dotimes [_ warmup-iters]
        (run-program prog))))

  (run [_]
    (swap! result + (run-program @program)))

  (checksum
    (bit-and @result 0xFFFFFFFF)))