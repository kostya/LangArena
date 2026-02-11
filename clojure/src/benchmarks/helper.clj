(ns benchmarks.helper)

(def ^:private ^:const IM 139968)
(def ^:private ^:const IA 3877)
(def ^:private ^:const IC 29573)
(def ^:private ^:const INIT 42)

(def ^:private last (atom INIT))

(defn reset []
  (reset! last INIT))

(defn next-int [max]
  (swap! last #(mod (+ (* % IA) IC) IM))
  (int (* (/ @last (double IM)) max)))

(defn next-int-range [from to]
  (+ (next-int (- to from 1)) from))

(defn next-float [max]
  (swap! last #(mod (+ (* % IA) IC) IM))
  (* max (/ @last (double IM))))

(defn checksum-str [v]
  (let [hash (atom 5381)]
    (doseq [c v]
      (swap! hash #(bit-and (+ (+ (bit-shift-left % 5) %) (int c)) 0xFFFFFFFF)))
    @hash))

(defn checksum-bytes [v]
  (let [hash (atom 5381)]
    (doseq [b v]
      (swap! hash #(bit-and (+ (+ (bit-shift-left % 5) %) (bit-and b 0xFF)) 0xFFFFFFFF)))
    @hash))