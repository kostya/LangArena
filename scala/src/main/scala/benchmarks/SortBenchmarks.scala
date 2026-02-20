package benchmarks

import scala.collection.mutable.ArrayBuffer

abstract class SortBenchmark extends Benchmark:
  protected var data: Array[Int] = _
  protected var resultVal: Long = 0L
  protected var sizeVal: Long = 0L

  override def prepare(): Unit =
    if sizeVal == 0L then
      sizeVal = configVal("size")
      data = Array.fill(sizeVal.toInt)(Helper.nextInt(1_000_000))

  def test(): Array[Int]

  override def run(iterationId: Int): Unit =
    resultVal += data(Helper.nextInt(sizeVal.toInt)).toLong
    val t = test()
    resultVal += t(Helper.nextInt(sizeVal.toInt)).toLong

  override def checksum(): Long = resultVal

class SortMerge extends SortBenchmark:
  private def mergeSortInplace(arr: Array[Int]): Unit =
    val temp = new Array[Int](arr.length)
    mergeSortHelper(arr, temp, 0, arr.length - 1)

  private def mergeSortHelper(arr: Array[Int], temp: Array[Int], left: Int, right: Int): Unit =
    if left >= right then return

    val mid = (left + right) / 2
    mergeSortHelper(arr, temp, left, mid)
    mergeSortHelper(arr, temp, mid + 1, right)
    merge(arr, temp, left, mid, right)

  private def merge(arr: Array[Int], temp: Array[Int], left: Int, mid: Int, right: Int): Unit =
    Array.copy(arr, left, temp, left, right - left + 1)

    var l = left
    var r = mid + 1
    var k = left

    while l <= mid && r <= right do
      if temp(l) <= temp(r) then
        arr(k) = temp(l)
        l += 1
      else
        arr(k) = temp(r)
        r += 1
      k += 1

    while l <= mid do
      arr(k) = temp(l)
      l += 1
      k += 1

  override def test(): Array[Int] =
    val arr = data.clone()
    mergeSortInplace(arr)
    arr

  override def name(): String = "SortMerge"

class SortQuick extends SortBenchmark:
  private def quickSort(arr: Array[Int], low: Int, high: Int): Unit =
    if low >= high then return

    val pivot = arr((low + high) / 2)
    var i = low
    var j = high

    while i <= j do
      while arr(i) < pivot do i += 1
      while arr(j) > pivot do j -= 1
      if i <= j then
        val temp = arr(i)
        arr(i) = arr(j)
        arr(j) = temp
        i += 1
        j -= 1

    quickSort(arr, low, j)
    quickSort(arr, i, high)

  override def test(): Array[Int] =
    val arr = data.clone()
    quickSort(arr, 0, arr.length - 1)
    arr

  override def name(): String = "SortQuick"

class SortSelf extends SortBenchmark:
  override def test(): Array[Int] =
    val arr = data.clone()
    scala.util.Sorting.quickSort(arr)
    arr

  override def name(): String = "SortSelf"
