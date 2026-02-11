(ns main
  (:require [benchmarks.core :as core])
  (:import [java.time Instant])
  (:gen-class))

(defn -main [& args]
  (let [now (.toEpochMilli (Instant/now))]
    (println "start:" now)

    (let [config-file (first (filter #(.endsWith % ".js") args))
          single-bench (first (remove #(.endsWith % ".js") args))]

      (try
        (core/load-config config-file)
        (catch Exception e
          (println "Error loading config:" (.getMessage e))
          (System/exit 1)))

      (require 
      		'[benchmarks.pidigits]
        '[benchmarks.binarytrees]
        '[benchmarks.brainfuck-array]
        '[benchmarks.brainfuck-recursion]

        :reload)

      (core/run-all single-bench)

      (System/exit 0))))