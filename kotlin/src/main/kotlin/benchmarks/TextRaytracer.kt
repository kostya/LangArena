package benchmarks

import Benchmark
import kotlin.math.*

class TextRaytracer : Benchmark() {
    companion object {
        private data class Vector(val x: Double, val y: Double, val z: Double) {
            fun scale(s: Double) = Vector(x * s, y * s, z * s)
            operator fun plus(other: Vector) = Vector(x + other.x, y + other.y, z + other.z)
            operator fun minus(other: Vector) = Vector(x - other.x, y - other.y, z - other.z)
            fun dot(other: Vector) = x * other.x + y * other.y + z * other.z
            fun magnitude(): Double {
                val d = dot(this)
                return if (d > 0.0) sqrt(d) else 0.0
            }
            fun normalize(): Vector {
                val mag = magnitude()
                return if (mag == 0.0) Vector(0.0, 0.0, 0.0) else scale(1.0 / mag)
            }
        }

        private data class Ray(val orig: Vector, val dir: Vector)

        private data class Color(val r: Double, val g: Double, val b: Double) {
            fun scale(s: Double) = Color(r * s, g * s, b * s)
            operator fun plus(other: Color) = Color(r + other.r, g + other.g, b + other.b)
        }

        private data class Sphere(val center: Vector, val radius: Double, val color: Color) {
            fun getNormal(pt: Vector) = (pt - center).normalize()
        }

        private data class Light(val position: Vector, val color: Color)

        private data class Hit(val obj: Sphere, val value: Double)

        private val WHITE = Color(1.0, 1.0, 1.0)
        private val RED = Color(1.0, 0.0, 0.0)
        private val GREEN = Color(0.0, 1.0, 0.0)
        private val BLUE = Color(0.0, 0.0, 1.0)

        private val LIGHT1 = Light(Vector(0.7, -1.0, 1.7), WHITE)

        private val LUT = listOf('.', '-', '+', '*', 'X', 'M')

        private val SCENE = listOf(
            Sphere(Vector(-1.0, 0.0, 3.0), 0.3, RED),
            Sphere(Vector(0.0, 0.0, 3.0), 0.8, GREEN),
            Sphere(Vector(1.0, 0.0, 3.0), 0.4, BLUE)
        )
    }

    private var w: Long = 0
    private var h: Long = 0
    private var resultVal: UInt = 0u

    init {
        w = configVal("w")
        h = configVal("h")
    }

    private fun shadePixel(ray: Ray, obj: Sphere, tval: Double): Int {
        val pi = ray.orig + ray.dir.scale(tval)
        val color = diffuseShading(pi, obj, LIGHT1)
        val col = (color.r + color.g + color.b) / 3.0
        var idx = (col * 6.0).toInt()
        if (idx < 0) idx = 0
        if (idx >= 6) idx = 5
        return idx
    }

    private fun intersectSphere(ray: Ray, center: Vector, radius: Double): Double? {
        val l = center - ray.orig
        val tca = l.dot(ray.dir)
        if (tca < 0.0) return null

        val d2 = l.dot(l) - tca * tca
        val r2 = radius * radius
        if (d2 > r2) return null

        val thc = sqrt(r2 - d2)
        val t0 = tca - thc
        if (t0 > 10000.0) return null  

        return t0
    }

    private fun clamp(x: Double, a: Double, b: Double): Double {
        return when {
            x < a -> a
            x > b -> b
            else -> x
        }
    }

    private fun diffuseShading(pi: Vector, obj: Sphere, light: Light): Color {
        val n = obj.getNormal(pi)
        val lam1 = (light.position - pi).normalize().dot(n)
        val lam2 = clamp(lam1, 0.0, 1.0)
        return light.color.scale(lam2 * 0.5) + obj.color.scale(0.3)
    }

    override fun run(iterationId: Int) {
        val fw = w.toDouble()
        val fh = h.toDouble()

        for (j in 0 until h.toInt()) {
            for (i in 0 until w.toInt()) {
                val fi = i.toDouble()
                val fj = j.toDouble()

                val ray = Ray(
                    Vector(0.0, 0.0, 0.0),
                    Vector((fi - fw / 2.0) / fw, (fj - fh / 2.0) / fh, 1.0).normalize()
                )

                var hit: Hit? = null

                for (obj in SCENE) {
                    val ret = intersectSphere(ray, obj.center, obj.radius)
                    if (ret != null) {
                        hit = Hit(obj, ret)
                        break
                    }
                }

                val pixel = if (hit != null) {
                    val shade = shadePixel(ray, hit.obj, hit.value)
                    LUT[shade]
                } else {
                    ' '
                }

                resultVal += pixel.code.toUInt()  
            }
        }
    }

    override fun checksum(): UInt = resultVal

    override fun name(): String = "TextRaytracer"
}