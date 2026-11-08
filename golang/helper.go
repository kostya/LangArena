package main

import (
	"encoding/json/jsontext"
	"encoding/json/v2"
	"fmt"
	"os"
	"strconv"
)

type CfgNumber struct {
	IntValue    int64
	StringValue string
	IsInt       bool
}

func (n *CfgNumber) UnmarshalJSON(data []byte) error {
	str := string(data)

	if i, err := strconv.ParseInt(str, 10, 64); err == nil {
		n.IntValue = i
		n.IsInt = true
		return nil
	}

	n.StringValue = str
	n.IsInt = false
	return nil
}

var (
	CONFIG = make(map[string]map[string]CfgNumber)
	ORDER  = make([]string, 0)
)

const (
	IM   = int64(139968)
	IA   = int64(3877)
	IC   = int64(29573)
	INIT = int64(42)
)

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

type Helper struct{}

var (
	last   = INIT
	global = &last
)

func Reset() {
	last = INIT
}

func NextInt(max int) int {
	*global = (*global*IA + IC) % IM
	return int(float64(*global) / float64(IM) * float64(max))
}

func NextFloat(max float64) float64 {
	*global = (*global*IA + IC) % IM
	return max * float64(*global) / float64(IM)
}

func Checksum(v string) uint32 {
	hash := uint32(5381)
	for i := 0; i < len(v); i++ {
		hash = ((hash << 5) + hash) + uint32(v[i])
	}
	return hash
}

func ChecksumBytes(v []byte) uint32 {
	hash := uint32(5381)
	for _, b := range v {
		hash = ((hash << 5) + hash) + uint32(b)
	}
	return hash
}

func ChecksumFloat64(v float64) uint32 {
	return Checksum(fmt.Sprintf("%.7f", v))
}

func LoadConfig(filename string) {
	data, err := os.ReadFile(filename)
	if err != nil {
		panic(err)
	}

	var jsonArray []map[string]jsontext.Value
	err = json.Unmarshal(data, &jsonArray)
	if err != nil {
		panic(err)
	}

	CONFIG = make(map[string]map[string]CfgNumber)
	ORDER = make([]string, 0)

	for _, item := range jsonArray {
		var name string
		if nameRaw, ok := item["name"]; ok {
			json.Unmarshal(nameRaw, &name)
		}

		if name == "" {
			continue
		}

		configMap := make(map[string]CfgNumber)
		for key, valueRaw := range item {
			if key == "name" {
				continue
			}
			var num CfgNumber
			json.Unmarshal(valueRaw, &num)
			configMap[key] = num
		}

		CONFIG[name] = configMap
		ORDER = append(ORDER, name)
	}
}

func configI64(class_name, field_name string) int64 {
	if cfg, ok := CONFIG[class_name]; ok {
		if n, ok := cfg[field_name]; ok {
			if n.IsInt {
				return n.IntValue
			} else {
				panic(fmt.Sprintf("Config for %s, not found i64 field: %s, found %s", class_name, field_name, n.StringValue))
			}
		}
		panic(fmt.Sprintf("Config for %s, not found i64 field: %s", class_name, field_name))
	}
	panic(fmt.Sprintf("Config not found class %s", class_name))
}

func configS(class_name, field_name string) string {
	if cfg, ok := CONFIG[class_name]; ok {
		if n, ok := cfg[field_name]; ok {
			if !n.IsInt {
				return n.StringValue
			} else {
				panic(fmt.Sprintf("Config for %s, not found string field: %s, found %d", class_name, field_name, n.IntValue))
			}
		}
		panic(fmt.Sprintf("Config for %s, not found string field: %s", class_name, field_name))
	}
	panic(fmt.Sprintf("Config not found class %s", class_name))
}
