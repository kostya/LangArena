package main

import (
	"encoding/json/v2"
	"fmt"
	"math"
)

type Coordinate struct {
	X    float64                   `json:"x"`
	Y    float64                   `json:"y"`
	Z    float64                   `json:"z"`
	Name string                    `json:"name"`
	Opts map[string][2]interface{} `json:"opts"`
}

type JsonGenerate struct {
	BaseBenchmark
	n      int64
	data   []Coordinate
	text   []byte
	result uint32
}

func round(val float64, precision int) float64 {
	ratio := math.Pow(10, float64(precision))
	return math.Round(val*ratio) / ratio
}

func (j *JsonGenerate) Prepare() {
	j.n = j.ConfigVal("coords")
	j.data = make([]Coordinate, j.n)
	for i := 0; i < int(j.n); i++ {
		j.data[i] = Coordinate{
			X:    round(NextFloat(1.0), 8),
			Y:    round(NextFloat(1.0), 8),
			Z:    round(NextFloat(1.0), 8),
			Name: fmt.Sprintf("%.7f %d", NextFloat(1.0), NextInt(10000)),
			Opts: map[string][2]interface{}{
				"1": {1, true},
			},
		}
	}
}

func (j *JsonGenerate) Run(iteration_id int) {
	type Response struct {
		Coordinates []Coordinate `json:"coordinates"`
		Info        string       `json:"info"`
	}

	resp := Response{
		Coordinates: j.data,
		Info:        "some info",
	}

	j.text, _ = json.Marshal(resp)

	if len(j.text) >= 15 && string(j.text[:15]) == "{\"coordinates\":" {
		j.result++
	}
}

func (j *JsonGenerate) Checksum() uint32 {
	return j.result
}

type JsonParseDom struct {
	BaseBenchmark
	text   []byte
	result uint32
}

func (j *JsonParseDom) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "Json::ParseDom"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text
}

func (j *JsonParseDom) calc() (float64, float64, float64) {
	var data map[string]interface{}
	json.Unmarshal(j.text, &data)

	coordinates := data["coordinates"].([]interface{})
	length := float64(len(coordinates))
	x, y, z := 0.0, 0.0, 0.0

	for _, coord := range coordinates {
		c := coord.(map[string]interface{})
		x += c["x"].(float64)
		y += c["y"].(float64)
		z += c["z"].(float64)
	}

	return x / length, y / length, z / length
}

func (j *JsonParseDom) Run(iteration_id int) {
	x, y, z := j.calc()
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseDom) Checksum() uint32 {
	return j.result
}

type JsonParseMapping struct {
	BaseBenchmark
	text   []byte
	result uint32
}

func (j *JsonParseMapping) Prepare() {
	gen := &JsonGenerate{BaseBenchmark: BaseBenchmark{className: "Json::ParseMapping"}}
	gen.n = j.ConfigVal("coords")
	gen.Prepare()
	gen.Run(0)
	j.text = gen.text
}

func (j *JsonParseMapping) calc() (float64, float64, float64) {
	var data struct {
		Coordinates []struct {
			X float64 `json:"x"`
			Y float64 `json:"y"`
			Z float64 `json:"z"`
		} `json:"coordinates"`
	}

	json.Unmarshal(j.text, &data)

	length := float64(len(data.Coordinates))
	x, y, z := 0.0, 0.0, 0.0

	for _, coord := range data.Coordinates {
		x += coord.X
		y += coord.Y
		z += coord.Z
	}

	return x / length, y / length, z / length
}

func (j *JsonParseMapping) Run(iteration_id int) {
	x, y, z := j.calc()
	j.result += ChecksumFloat64(x) + ChecksumFloat64(y) + ChecksumFloat64(z)
}

func (j *JsonParseMapping) Checksum() uint32 {
	return j.result
}
