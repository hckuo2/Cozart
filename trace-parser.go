package main

import (
	"bufio"
	"debug/elf"
	"fmt"
	"log"
	"os"
	"regexp"
	"sort"
	"strconv"
	"sync"
)

func check(e error) {
	if e != nil {
		panic(e)
	}
}
func Max(x, y uint64) uint64 {
	if x < y {
		return y
	}
	return x
}

func getTextSize() uint64 {
	elf, err := elf.Open("vmlinux")
	if err != nil {
		log.Println(err)
		return 0
	}
	sec := elf.Section(".text")
	return sec.SectionHeader.Size
}

const startMark uint64 = 0x333333333000
const endMark uint64 = 0x222222222000
const kernelText uint64 = 0xffffffff81000000

var textSize uint64
var kernelTextEnd uint64

type Block struct {
	start     uint64
	end       uint64
	timestamp float64
}

func (b Block) String() string {
	return fmt.Sprintf("%x %x %f\n", b.start, b.end, b.timestamp)
}

func parse(jobs <-chan string, results chan<- Block, wg *sync.WaitGroup) {
	defer wg.Done()
	regex := regexp.MustCompile(`^\d+@(\d+.\d+):exec_tb_block.+pc=0x([0-9a-fA-F]+) size=(\d+)`)
	for line := range jobs {
		matches := regex.FindStringSubmatch(line)
		if len(matches) != 4 {
			log.Println("match error ", len(matches), matches)
			continue
		}
		timestamp, _ := strconv.ParseFloat(matches[1], 64)
		start, _ := strconv.ParseUint(matches[2], 16, 64)
		size, _ := strconv.ParseUint(matches[3], 10, 64)
        if start > kernelText || (start+size) < kernelTextEnd ||
            start == startMark || start == endMark {
			results <- Block{start, start + size, timestamp}
		}
	}
}

func main() {
	textSize = getTextSize()
    kernelTextEnd = kernelTextEnd + textSize
	scanner := bufio.NewScanner(os.Stdin)
	jobs := make(chan string)
	results := make(chan Block)
	wg := new(sync.WaitGroup)
	for w := 0; w < 4; w++ {
		wg.Add(1)
		go parse(jobs, results, wg)
	}
	go func() {
		for scanner.Scan() {
			jobs <- scanner.Text()
		}
		close(jobs)
	}()
	go func() {
		wg.Wait()
		close(results)
	}()
	blocks := make(map[uint64]Block)
	for b := range results {
		blocks[b.start] = b
	}

	startTime := blocks[startMark].timestamp
	endTime := blocks[endMark].timestamp

	var keys []uint64
	for k, b := range blocks {
		if b.timestamp < startTime || b.timestamp > endTime {
			continue
		}
		keys = append(keys, k)
	}
	log.Printf("[Block Count] before filter: %d\t after filter: %d\n",
		len(blocks), len(keys))
	sort.Slice(keys, func(i, j int) bool { return keys[i] < keys[j] })
	for i, start := range keys {
		end := blocks[start].end
		for i != len(keys)-1 {
			n_start := keys[i+1]
			n_end := blocks[n_start].end
			if n_start > end {
				break
			}
			end = Max(n_end, end)
			i++
		}
		fmt.Printf("%x,%x\n", start, end-start)
	}
}
