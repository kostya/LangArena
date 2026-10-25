package main

type BufferHashSHA256 struct {
	BaseBenchmark
	data   []byte
	result uint32
}

func (b *BufferHashSHA256) Prepare() {
	size := int(b.ConfigVal("size"))
	b.data = make([]byte, size)
	for i := 0; i < size; i++ {
		b.data[i] = byte(NextInt(256))
	}
}

func (b *BufferHashSHA256) test() uint32 {
	hashes := [8]uint32{
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
		0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
	}

	for i, byteVal := range b.data {
		hashIdx := i % 8
		hash := hashes[hashIdx]
		hash = ((hash << 5) + hash) + uint32(byteVal)
		hash = (hash + (hash << 10)) ^ (hash >> 6)
		hashes[hashIdx] = hash
	}

	result := make([]byte, 32)
	for i := 0; i < 8; i++ {
		hash := hashes[i]
		result[i*4] = byte(hash >> 24)
		result[i*4+1] = byte(hash >> 16)
		result[i*4+2] = byte(hash >> 8)
		result[i*4+3] = byte(hash)
	}

	return uint32(result[0]) | uint32(result[1])<<8 |
		uint32(result[2])<<16 | uint32(result[3])<<24
}

func (b *BufferHashSHA256) Run(iteration_id int) {
	ch := byte(NextInt(256))
	b.data[NextInt(len(b.data))] = ch
	b.result += b.test()
}

func (b *BufferHashSHA256) Checksum() uint32 {
	return b.result
}

type BufferHashCRC32 struct {
	BaseBenchmark
	data   []byte
	result uint32
}

func (b *BufferHashCRC32) Prepare() {
	size := int(b.ConfigVal("size"))
	b.data = make([]byte, size)
	for i := 0; i < size; i++ {
		b.data[i] = byte(NextInt(256))
	}
}

func (b *BufferHashCRC32) test() uint32 {
	crc := uint32(0xFFFFFFFF)

	for _, byteVal := range b.data {
		crc = crc ^ uint32(byteVal)
		for j := 0; j < 8; j++ {
			if (crc & 1) != 0 {
				crc = (crc >> 1) ^ 0xEDB88320
			} else {
				crc = crc >> 1
			}
		}
	}

	return crc ^ 0xFFFFFFFF
}

func (b *BufferHashCRC32) Run(iteration_id int) {
	ch := byte(NextInt(256))
	b.data[NextInt(len(b.data))] = ch
	b.result += b.test()
}

func (b *BufferHashCRC32) Checksum() uint32 {
	return b.result
}
