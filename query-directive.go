package main
import (
    "io/ioutil"
    "strings"
    "sort"
    "os"
    "strconv"
    "bufio"
    "fmt"
)

func main () {
    data, err := ioutil.ReadFile("directives.db")
    if err != nil {
        panic(err)
    }
    db := strings.Split(string(data), "\n")
    scanner := bufio.NewScanner(os.Stdin)
    for scanner.Scan() {
        query := scanner.Text()
        i := sort.Search(len(db), func(i int) bool {
            line := db[i]
            vs := strings.Split(line, ":")
            vs1 := strings.Split(query, ":")
            r := strings.Compare(vs[0], vs1[0])
            if r == 0 {
                l1, _ := strconv.ParseInt(vs[1], 10, 32)
                l2, _ := strconv.ParseInt(vs1[1], 10, 32)
                return l1 > l2
            }
            return r > 0
        })
        if i == 0 {
            continue
        }
        results := strings.Split(db[i-1], ":")
        if len(results) < 3 || strings.Contains(results[2], "#endif") {
            continue
        } else {
            fmt.Println(results)
        }
    }
}
