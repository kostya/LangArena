(ns benchmarks.pidigits
  (:require [benchmarks.core :refer [bench config-i64]]
            [benchmarks.helper :refer [checksum-str]])
  (:import [java.math BigInteger]
           [java.io ByteArrayOutputStream]))

(defn- compute-pidigits [nn baos]
  (loop [i 0
         k 0
         ns BigInteger/ZERO
         a BigInteger/ZERO
         k1 1
         n BigInteger/ONE
         d BigInteger/ONE]

    (if (>= i nn)

      (when (> (.compareTo ns BigInteger/ZERO) 0)
        (let [line (format (str "%0" (mod nn 10) "d\t:%d\n")
                          (.longValue ns) nn)]
          (.write baos (.getBytes line))))

      (let [k' (inc k)
            t (.shiftLeft n 1)
            n' (.multiply n (BigInteger/valueOf k'))
            k1' (+ k1 2)
            a' (.multiply (.add a t) (BigInteger/valueOf k1'))
            d' (.multiply d (BigInteger/valueOf k1'))]

        (if (>= (.compareTo a' n') 0)

          (let [temp (.add (.multiply n' (BigInteger/valueOf 3)) a')
                quotient (.divide temp d')
                remainder (.remainder temp d')
                u (.add remainder n')]

            (if (> (.compareTo d' u) 0)

              (let [ns' (.add (.multiply ns BigInteger/TEN) quotient)
                    i' (inc i)
                    a'' (.multiply (.subtract a' (.multiply d' quotient))
                                  BigInteger/TEN)
                    n'' (.multiply n' BigInteger/TEN)]

                (if (zero? (mod i' 10))

                  (let [line (format "%010d\t:%d\n" (.longValue ns') i')]
                    (.write baos (.getBytes line))
                    (recur i' k' BigInteger/ZERO a'' k1' n'' d'))  

                  (recur i' k' ns' a'' k1' n'' d')))  

              (recur i k' ns a' k1' n' d')))  

          (recur i k' ns a' k1' n' d'))))))  

(bench "Pidigits"
  (let [nn (atom 0)
        result (atom nil)])

  (init
    (reset! nn (config-i64 "Pidigits" "amount"))
    (reset! result (ByteArrayOutputStream.)))

  (run [_]
    (let [nn-val @nn
          baos @result]
      (compute-pidigits nn-val baos)))

  (checksum
    (checksum-str (.toString @result))))