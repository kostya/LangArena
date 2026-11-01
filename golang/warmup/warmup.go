package main

import (
	"bytes"
	"container/heap"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

func _warmup() {
	_ = bytes.MinRead
	_ = heap.Init
	_ = base64.StdEncoding
	_ = csv.NewReader
	_ = json.Marshal
	_ = fmt.Sprint
	_ = math.Pi
	_ = os.Args
	_ = regexp.MustCompile
	_ = runtime.GOOS
	_ = sort.Ints
	_ = strconv.Itoa
	_ = strings.TrimSpace
	_ = sync.Mutex{}
	_ = time.Now
}

func main() {}
