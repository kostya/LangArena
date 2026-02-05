module benchmarks.sort;

import std.stdio;
import std.conv;
import std.array;
import std.algorithm;
import std.random;
import benchmark;
import helper;

class SortBenchmark : Benchmark {
protected:
    int[] data;
    int sizeVal;
    uint resultVal;

    this() {
        resultVal = 0;
        sizeVal = 0;
    }

    abstract int[] test();

protected:
    override string className() const { return "SortBenchmark"; }

public:
    override void prepare() {
        if (sizeVal == 0) {
            sizeVal = configVal("size");
            data.length = sizeVal;

            foreach (i; 0 .. sizeVal) {
                data[i] = Helper.nextInt(1_000_000);
            }
        }
    }

    override void run(int iterationId) {

        resultVal += data[Helper.nextInt(cast(int)sizeVal)];

        int[] t = test();
        resultVal += t[Helper.nextInt(cast(int)sizeVal)];
    }

    override uint checksum() {
        return resultVal;
    }
}

class SortQuick : SortBenchmark {
private:
    void quickSort(ref int[] arr, int low, int high) {
        if (low >= high) return;

        int pivot = arr[(low + high) / 2];
        int i = low, j = high;

        while (i <= j) {
            while (arr[i] < pivot) i++;
            while (arr[j] > pivot) j--;
            if (i <= j) {
                swap(arr[i], arr[j]);
                i++;
                j--;
            }
        }

        quickSort(arr, low, j);
        quickSort(arr, i, high);
    }

protected:
    override string className() const { return "SortQuick"; }

public:
    override int[] test() {
        int[] arr = data.dup;  
        quickSort(arr, 0, cast(int)(arr.length - 1));
        return arr;
    }
}

class SortMerge : SortBenchmark {
private:
    void mergeSortInplace(ref int[] arr) {
        int[] temp = new int[arr.length];
        mergeSortHelper(arr, temp, 0, cast(int)(arr.length - 1));
    }

    void mergeSortHelper(ref int[] arr, ref int[] temp, int left, int right) {
        if (left >= right) return;

        int mid = (left + right) / 2;
        mergeSortHelper(arr, temp, left, mid);
        mergeSortHelper(arr, temp, mid + 1, right);
        merge(arr, temp, left, mid, right);
    }

    void merge(ref int[] arr, ref int[] temp, int left, int mid, int right) {
        foreach (i; left .. right + 1) {
            temp[i] = arr[i];
        }

        int i = left;
        int j = mid + 1;
        int k = left;

        while (i <= mid && j <= right) {
            if (temp[i] <= temp[j]) {
                arr[k] = temp[i];
                i++;
            } else {
                arr[k] = temp[j];
                j++;
            }
            k++;
        }

        while (i <= mid) {
            arr[k] = temp[i];
            i++;
            k++;
        }
    }

protected:
    override string className() const { return "SortMerge"; }

public:
    override int[] test() {
        int[] arr = data.dup;  
        mergeSortInplace(arr);
        return arr;
    }
}

class SortSelf : SortBenchmark {
protected:
    override string className() const { return "SortSelf"; }

public:
    override int[] test() {
        int[] arr = data.dup;  
        sort(arr);  
        return arr;
    }
}