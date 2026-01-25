package benchmarks

import Benchmark
import kotlin.math.*

class Noise : Benchmark() {
    companion object {
        private const val SIZE = 64
        private val SYM = listOf(' ', '░', '▒', '▓', '█', '█')
        
        private data class Vec2(val x: Double, val y: Double)
        
        private fun lerp(a: Double, b: Double, v: Double): Double {
            return a * (1.0 - v) + b * v
        }
        
        private fun smooth(v: Double): Double {
            return v * v * (3.0 - 2.0 * v)
        }
        
        private fun randomGradient(): Vec2 {
            val v = Helper.nextFloat() * PI * 2.0
            return Vec2(cos(v), sin(v))
        }
        
        private fun gradient(orig: Vec2, grad: Vec2, p: Vec2): Double {
            val sp = Vec2(p.x - orig.x, p.y - orig.y)
            return grad.x * sp.x + grad.y * sp.y
        }
    }
    
    private class Noise2DContext {
        private val rgradients = Array(SIZE) { randomGradient() }
        private val permutations = IntArray(SIZE) { it }
        
        init {
            repeat(SIZE) {
                val a = Helper.nextInt(SIZE)
                val b = Helper.nextInt(SIZE)
                val temp = permutations[a]
                permutations[a] = permutations[b]
                permutations[b] = temp
            }
        }
        
        private fun getGradient(x: Int, y: Int): Vec2 {
            val idx = permutations[x and (SIZE - 1)] + permutations[y and (SIZE - 1)]
            return rgradients[idx and (SIZE - 1)]  // КАК В C++!
        }
        
        private fun getGradients(x: Double, y: Double): Pair<List<Vec2>, List<Vec2>> {
            val x0f = floor(x)
            val y0f = floor(y)
            val x0 = x0f.toInt()
            val y0 = y0f.toInt()
            
            val gradients = listOf(
                getGradient(x0, y0),
                getGradient(x0 + 1, y0),
                getGradient(x0, y0 + 1),
                getGradient(x0 + 1, y0 + 1)
            )
            
            val origins = listOf(
                Vec2(x0f + 0.0, y0f + 0.0),
                Vec2(x0f + 1.0, y0f + 0.0),
                Vec2(x0f + 0.0, y0f + 1.0),
                Vec2(x0f + 1.0, y0f + 1.0)
            )
            
            return Pair(gradients, origins)
        }
        
        fun get(x: Double, y: Double): Double {
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
    
    private var n: Int = 0
    private var _result: ULong = 0uL
    
    init {
        n = iterations
    }
    
    private fun noise(): ULong {
        val pixels = Array(SIZE) { DoubleArray(SIZE) }
        val n2d = Noise2DContext()
        
        repeat(100) { i ->
            for (y in 0 until SIZE) {
                for (x in 0 until SIZE) {
                    val v = n2d.get(x * 0.1, (y + (i * 128)) * 0.1) * 0.5 + 0.5
                    pixels[y][x] = v
                }
            }
        }
        
        var res: ULong = 0uL
        
        for (y in 0 until SIZE) {
            for (x in 0 until SIZE) {
                val v = pixels[y][x]
                val idx = (v / 0.2).toInt()
                val clampedIdx = if (idx >= 6) 5 else idx
                res += SYM[clampedIdx].code.toULong()
            }
        }
        
        return res
    }
    
    override fun run() {
        repeat(n) {
            val v = noise()
            _result += v
        }
    }
    
    override val result: Long
        get() = _result.toLong()
}