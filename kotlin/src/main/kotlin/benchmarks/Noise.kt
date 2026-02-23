package benchmarks

import Benchmark
import kotlin.math.*

class Noise : Benchmark() {
    companion object {
        private val SYM = listOf(' ', '░', '▒', '▓', '█', '█')

        private data class Vec2(
            val x: Double,
            val y: Double,
        )

        private fun lerp(
            a: Double,
            b: Double,
            v: Double,
        ): Double = a * (1.0 - v) + b * v

        private fun smooth(v: Double): Double = v * v * (3.0 - 2.0 * v)

        private fun randomGradient(): Vec2 {
            val v = Helper.nextFloat() * PI * 2.0
            return Vec2(cos(v), sin(v))
        }

        private fun gradient(
            orig: Vec2,
            grad: Vec2,
            p: Vec2,
        ): Double {
            val sp = Vec2(p.x - orig.x, p.y - orig.y)
            return grad.x * sp.x + grad.y * sp.y
        }
    }

    private class Noise2DContext(
        private val sizeVal: Int,
    ) {
        private val rgradients = Array(sizeVal) { randomGradient() }
        private val permutations = IntArray(sizeVal) { it }

        init {
            repeat(sizeVal) {
                val a = Helper.nextInt(sizeVal)
                val b = Helper.nextInt(sizeVal)
                val temp = permutations[a]
                permutations[a] = permutations[b]
                permutations[b] = temp
            }
        }

        private fun getGradient(
            x: Int,
            y: Int,
        ): Vec2 {
            val idx = permutations[x and (sizeVal - 1)] + permutations[y and (sizeVal - 1)]
            return rgradients[idx and (sizeVal - 1)]
        }

        private fun getGradients(
            x: Double,
            y: Double,
        ): Pair<List<Vec2>, List<Vec2>> {
            val x0f = floor(x)
            val y0f = floor(y)
            val x0 = x0f.toInt()
            val y0 = y0f.toInt()

            val gradients =
                listOf(
                    getGradient(x0, y0),
                    getGradient(x0 + 1, y0),
                    getGradient(x0, y0 + 1),
                    getGradient(x0 + 1, y0 + 1),
                )

            val origins =
                listOf(
                    Vec2(x0f + 0.0, y0f + 0.0),
                    Vec2(x0f + 1.0, y0f + 0.0),
                    Vec2(x0f + 0.0, y0f + 1.0),
                    Vec2(x0f + 1.0, y0f + 1.0),
                )

            return Pair(gradients, origins)
        }

        fun get(
            x: Double,
            y: Double,
        ): Double {
            val p = Vec2(x, y)
            val (gradients, origins) = getGradients(x, y)

            val v0 = gradient(origins[0], gradients[0], p)
            val v1 = gradient(origins[1], gradients[1], p)
            val v2 = gradient(origins[2], gradients[2], p)
            val v3 = gradient(origins[3], gradients[3], p)

            val fx = smooth(x - origins[0].x)
            val vx0 = lerp(v0, v1, fx)
            val vx1 = lerp(v2, v3, fx)

            val fy = smooth(y - origins[0].y)
            return lerp(vx0, vx1, fy)
        }
    }

    private var sizeVal: Long = 0
    private var resultVal: UInt = 0u
    private lateinit var n2d: Noise2DContext

    init {
        sizeVal = configVal("size")
        n2d = Noise2DContext(sizeVal.toInt())
    }

    override fun run(iterationId: Int) {
        for (y in 0 until sizeVal.toInt()) {
            for (x in 0 until sizeVal.toInt()) {
                val v = n2d.get(x * 0.1, (y + (iterationId * 128)) * 0.1) * 0.5 + 0.5
                val idx = (v / 0.2).toInt()
                val clampedIdx = if (idx >= 6) 5 else idx
                resultVal += SYM[clampedIdx].code.toUInt()
            }
        }
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "Etc::Noise"
}
