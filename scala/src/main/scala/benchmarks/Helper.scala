package benchmarks

import java.nio.file.{Files, Paths}
import java.util.Locale
import org.json.JSONObject
import scala.util.Using

object Helper:
  private val IM = 139968
  private val IA = 3877
  private val IC = 29573
  private val INIT = 42

  private var last = INIT

  private val numberFormat = java.text.NumberFormat.getInstance(java.util.Locale.US)
  numberFormat.setGroupingUsed(false)
  numberFormat.setMinimumFractionDigits(3)
  numberFormat.setMaximumFractionDigits(3)

  def formatTime(seconds: Double): String = 
    numberFormat.format(seconds)

  def reset(): Unit =
    last = INIT

  def nextInt(max: Int): Int =
    last = (last * IA + IC) % IM
    ((last / IM.toDouble) * max).toInt

  def nextInt(from: Int, to: Int): Int =
    nextInt(to - from + 1) + from

  def nextFloat(max: Double): Double =
    last = (last * IA + IC) % IM
    max * last / IM.toDouble

  def nextFloat(): Double = nextFloat(1.0)

  def debug(message: => String): Unit =
    if sys.env.getOrElse("DEBUG", "0") == "1" then
      println(message)

  def checksum(v: String): Long =
    var hash: Long = 5381
    for c <- v.toCharArray do
      hash = (hash << 5) + hash + c
    hash & 0xFFFFFFFFL

  def checksum(v: Array[Byte]): Long =
    var hash: Long = 5381
    for b <- v do
      hash = (hash << 5) + hash + (b & 0xFF)
    hash & 0xFFFFFFFFL

  def checksumF64(v: Double): Long =
    checksum(String.format(Locale.US, "%.7f", v)) & 0xFFFFFFFFL

  @volatile var CONFIG: JSONObject = new JSONObject()

  def loadConfig(filename: String): Unit =
    val file = Option(filename).getOrElse("../test.js")
    val content = Files.readString(Paths.get(file))
    CONFIG = new JSONObject(content)

  def configI64(className: String, fieldName: String): Long =
    try
      if CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName) then
        CONFIG.getJSONObject(className).getLong(fieldName)
      else
        throw RuntimeException(s"Config not found for $className, field: $fieldName")
    catch
      case e: Exception =>
        System.err.println(e.getMessage)
        0L

  def configS(className: String, fieldName: String): String =
    try
      if CONFIG.has(className) && CONFIG.getJSONObject(className).has(fieldName) then
        CONFIG.getJSONObject(className).getString(fieldName)
      else
        throw RuntimeException(s"Config not found for $className, field: $fieldName")
    catch
      case e: Exception =>
        System.err.println(e.getMessage)
        ""

  private def inspect(str: String): String =
    val sb = new StringBuilder("\"")
    for c <- str.toCharArray do
      c match
        case '\n' => sb.append("\\n")
        case '\r' => sb.append("\\r")
        case '\t' => sb.append("\\t")
        case '\\' => sb.append("\\\\")
        case '\"' => sb.append("\\\"")
        case _ =>
          if c >= ' ' && c <= '~' then sb.append(c)
          else sb.append(f"\\u$c%04x")
    sb.append("\"")
    sb.toString