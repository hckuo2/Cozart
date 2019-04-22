package main
import (
    "io/ioutil"
    "strings"
    "os"
    "strconv"
    "bufio"
    "fmt"
)

type Mapping struct{
    linenum int64
    text string
}

func main () {
    data, err := ioutil.ReadFile("directives.db")
    if err != nil {
        panic(err)
    }
    db := make(map[string][]Mapping)
    for _, line := range strings.Split(string(data), "\n") {
        cols := strings.Split(line, ":")
        if len(cols) != 3 {
            continue
        }
        filename := cols[0]
        linenum, _ := strconv.ParseInt(cols[1], 10, 32)
        db[filename] = append(db[filename], Mapping{linenum, cols[2]})
    }
    scanner := bufio.NewScanner(os.Stdin)
    for scanner.Scan() {
        query := scanner.Text()
        cols := strings.Split(query, ":")
        filename := cols[0]
        linenum,_ := strconv.ParseInt(cols[1], 10, 32)
        if mappings, ok := db[filename]; ok {
            for i, m := range mappings {
                if linenum < m.linenum {
                    if i > 0 {
                        fmt.Println(mappings[i-1].text)
                    }
                    break
                }
            }
        }
    }
}
