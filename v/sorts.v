module sorts

import benchmark
import helper

pub struct SortBenchmark {
	benchmark.BaseBenchmark
pub mut:
	data     []int
	size_val i64
mut:
	result_val u32
}

fn new_sort_benchmark(class_name string) SortBenchmark {
	return SortBenchmark{
		BaseBenchmark: benchmark.new_base_benchmark(class_name)
		size_val:      0
		result_val:    0
	}
}

pub struct SortQuick {
	SortBenchmark
}

pub fn new_sortquick() &benchmark.IBenchmark {
	mut bench := &SortQuick{
		SortBenchmark: new_sort_benchmark('Sort::Quick')
	}
	return bench
}

pub fn (b SortQuick) name() string {
	return 'Sort::Quick'
}

fn quick_sort(mut arr []int, low int, high int) {
	if low >= high {
		return
	}

	pivot := arr[(low + high) / 2]
	mut i := low
	mut j := high

	for i <= j {
		for arr[i] < pivot {
			i++
		}
		for arr[j] > pivot {
			j--
		}
		if i <= j {
			temp := arr[i]
			arr[i] = arr[j]
			arr[j] = temp
			i++
			j--
		}
	}

	quick_sort(mut arr, low, j)
	quick_sort(mut arr, i, high)
}

pub fn (mut b SortQuick) prepare() {
	b.size_val = int(helper.config_i64('Sort::Quick', 'size'))
	b.data = []int{len: int(b.size_val)}
	for i in 0 .. b.size_val {
		b.data[i] = int(helper.next_int(1_000_000))
	}
}

pub fn (mut b SortQuick) run(iteration_id int) {
	size := int(b.size_val)

	b.result_val += u32(b.data[helper.next_int(size)])

	mut arr := b.data.clone()
	quick_sort(mut arr, 0, arr.len - 1)

	b.result_val += u32(arr[helper.next_int(size)])
}

pub fn (b SortQuick) checksum() u32 {
	return b.result_val
}

pub struct SortMerge {
	SortBenchmark
}

pub fn new_sortmerge() &benchmark.IBenchmark {
	mut bench := &SortMerge{
		SortBenchmark: new_sort_benchmark('Sort::Merge')
	}
	return bench
}

pub fn (b SortMerge) name() string {
	return 'Sort::Merge'
}

fn merge_sort_inplace(mut arr []int) {
	mut temp := []int{len: arr.len}
	merge_sort_helper(mut arr, mut temp, 0, arr.len - 1)
}

fn merge_sort_helper(mut arr []int, mut temp []int, left int, right int) {
	if left >= right {
		return
	}

	mid := (left + right) / 2
	merge_sort_helper(mut arr, mut temp, left, mid)
	merge_sort_helper(mut arr, mut temp, mid + 1, right)
	merge(mut arr, mut temp, left, mid, right)
}

fn merge(mut arr []int, mut temp []int, left int, mid int, right int) {
	for i in left .. right + 1 {
		temp[i] = arr[i]
	}

	mut i := left
	mut j := mid + 1
	mut k := left

	for i <= mid && j <= right {
		if temp[i] <= temp[j] {
			arr[k] = temp[i]
			i++
		} else {
			arr[k] = temp[j]
			j++
		}
		k++
	}

	for i <= mid {
		arr[k] = temp[i]
		i++
		k++
	}
}

pub fn (mut b SortMerge) prepare() {
	b.size_val = int(helper.config_i64('Sort::Merge', 'size'))
	b.data = []int{len: int(b.size_val)}
	for i in 0 .. b.size_val {
		b.data[i] = int(helper.next_int(1_000_000))
	}
}

pub fn (mut b SortMerge) run(iteration_id int) {
	size := int(b.size_val)

	b.result_val += u32(b.data[helper.next_int(size)])

	mut arr := b.data.clone()
	merge_sort_inplace(mut arr)

	b.result_val += u32(arr[helper.next_int(size)])
}

pub fn (b SortMerge) checksum() u32 {
	return b.result_val
}

pub struct SortSelf {
	SortBenchmark
}

pub fn new_sortself() &benchmark.IBenchmark {
	mut bench := &SortSelf{
		SortBenchmark: new_sort_benchmark('Sort::Self')
	}
	return bench
}

pub fn (b SortSelf) name() string {
	return 'Sort::Self'
}

pub fn (mut b SortSelf) prepare() {
	b.size_val = int(helper.config_i64('Sort::Self', 'size'))
	b.data = []int{len: int(b.size_val)}
	for i in 0 .. b.size_val {
		b.data[i] = int(helper.next_int(1_000_000))
	}
}

pub fn (mut b SortSelf) run(iteration_id int) {
	size := int(b.size_val)

	b.result_val += u32(b.data[helper.next_int(size)])

	mut arr := b.data.clone()
	arr.sort()

	b.result_val += u32(arr[helper.next_int(size)])
}

pub fn (b SortSelf) checksum() u32 {
	return b.result_val
}
