(ns benchmarks.core
  (:require [cheshire.core :as json]
            [clojure.java.io :as io])
  (:import [java.util Locale]))

(Locale/setDefault Locale/US)

(defonce config (atom {}))

(defn load-config [filename]
  (reset! config (json/parse-string (slurp (or filename "../test.js")) true)))

(defn config-i64 [class-name field]
  (let [val (get-in @config [(keyword class-name) (keyword field)])]
    (cond
      (integer? val) val
      (string? val) (try (Long/parseLong val) (catch Exception _ 0))
      :else 0)))

(defn config-s [class-name field]
  (let [val (get-in @config [(keyword class-name) (keyword field)])]
    (cond
      (string? val) val
      (number? val) (str val)
      :else "")))

(defprotocol IBenchmark
  (bench-name [this])
  (init [this])                 
  (prepare [this])
  (run [this iteration-id])
  (checksum [this])

  (warmup [this])
  (warmupIterations [this])
  (expectedChecksum [this])
  (iterations [this]))

(defrecord BaseBenchmark [name-fn init-fn prepare-fn run-fn checksum-fn 
                         warmup-fn warmup-iterations-fn expected-fn iterations-fn]
  IBenchmark

  (bench-name [this] (name-fn this))

  (init [this]
    (when init-fn (init-fn this)))

  (prepare [this] 
    (when prepare-fn (prepare-fn this)))

  (run [this iteration-id] 
    (run-fn this iteration-id))

  (checksum [this] 
    (checksum-fn this))

  (warmup [this]
    (if warmup-fn
      (warmup-fn this)
      (let [warmup-count (warmupIterations this)]
        (dotimes [i warmup-count]
          (run this i)))))

  (warmupIterations [this]
    (if warmup-iterations-fn
      (warmup-iterations-fn this)
      (let [iters (config-i64 (bench-name this) "iterations")]
        (max (long (* iters 0.2)) 1))))

  (expectedChecksum [this]
    (if expected-fn
      (expected-fn this)
      (config-i64 (bench-name this) "checksum")))

  (iterations [this]
    (if iterations-fn
      (iterations-fn this)
      (config-i64 (bench-name this) "iterations"))))

(defn make-benchmark 
  [name & {:keys [init prepare run checksum 
                  warmup warmupIterations expectedChecksum iterations]}]
  (->BaseBenchmark 
    (constantly name)
    init
    prepare
    run
    checksum
    warmup
    warmupIterations
    expectedChecksum
    iterations))

(defmacro bench [name & forms]
  (let [let-form (first (filter #(= (first %) 'let) forms))
        init-form (first (filter #(= (first %) 'init) forms))
        prepare-form (first (filter #(= (first %) 'prepare) forms))
        run-form (first (filter #(= (first %) 'run) forms))
        checksum-form (first (filter #(= (first %) 'checksum) forms))
        warmup-form (first (filter #(= (first %) 'warmup) forms))
        warmup-iterations-form (first (filter #(= (first %) 'warmupIterations) forms))
        expected-checksum-form (first (filter #(= (first %) 'expectedChecksum) forms))
        iterations-form (first (filter #(= (first %) 'iterations) forms))

        run-args (second run-form)]

    `(register-benchmark
       (fn []
         (let ~(second let-form)

           (make-benchmark 
             ~(str name)

             ~@(when init-form
                 `[:init (fn [~'_] ~@(rest init-form))])

             :prepare (fn [~'_] ~@(rest prepare-form))

             :run ~(let [run-body (nthrest run-form 2)]
                     (cond

                       (and (vector? run-args) (= 1 (count run-args)))
                       `(fn [~'_ ~(first run-args)] ~@run-body)

                       (and (vector? run-args) (= 2 (count run-args)))
                       `(fn ~run-args ~@run-body)

                       :else
                       (throw (Exception. "run expect [iteration-id] or [_ iteration-id]"))))

             :checksum (fn [~'_] ~@(rest checksum-form))

             ~@(when warmup-form
                 (let [warmup-args (second warmup-form)
                       warmup-body (nthrest warmup-form 2)]
                   (if (vector? warmup-args)
                     `[:warmup (fn ~warmup-args ~@warmup-body)]
                     `[:warmup (fn [~'_] ~@(rest warmup-form))])))

             ~@(when warmup-iterations-form
                 `[:warmupIterations (fn [~'_] ~@(rest warmup-iterations-form))])

             ~@(when expected-checksum-form
                 `[:expectedChecksum (fn [~'_] ~@(rest expected-checksum-form))])

             ~@(when iterations-form
                 `[:iterations (fn [~'_] ~@(rest iterations-form))])))))))

(defonce benchmarks (atom []))

(defn register-benchmark [factory-fn]
  (swap! benchmarks conj factory-fn))

(defn run-benchmark [bench]
  (let [name (bench-name bench)
        iters (iterations bench)]

    (init bench)

    (flush)
    (prepare bench)
    (warmup bench)

    (let [start (System/nanoTime)]
      (dotimes [i iters]
        (run bench i))
      (let [time (/ (- (System/nanoTime) start) 1e9)
            actual (checksum bench)
            expected (expectedChecksum bench)]
        (println (format "%s: %s in %.3fs" 
                       name
                       (if (= actual expected) "OK" 
                           (format "ERR[actual=%d, expected=%d]" actual expected))
                       time))
        {:name name :time time :ok (= actual expected)}))))

(defn run-all [single-bench]
  (let [results (atom {})
        summary (atom {:total 0.0 :ok 0 :fails 0})]

    (doseq [factory @benchmarks]
      (let [bench (factory)
            name (bench-name bench)]
        (when (or (nil? single-bench)
                  (.contains (.toLowerCase name) 
                           (.toLowerCase (or single-bench ""))))
          (when-let [result (run-benchmark bench)]
            (swap! results assoc name (:time result))
            (swap! summary (fn [s]
                             (-> s
                                 (update :total + (:time result))
                                 (update (if (:ok result) :ok :fails) inc))))))))

    (spit "/tmp/results.js" (json/generate-string @results))

    (let [s @summary
          total (+ (:ok s) (:fails s))]
      (println (format "Summary: %.4fs, %d, %d, %d" 
                     (:total s) total (:ok s) (:fails s)))
      (when (pos? (:fails s)) (System/exit 1)))))