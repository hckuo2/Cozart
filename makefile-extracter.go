package main
import (
    "fmt"
    "io/ioutil"
    "os"
    "strings"
    "regexp"
    "bufio"
    "log"
)

func main() {
    scanner := bufio.NewScanner(os.Stdin)
    for scanner.Scan() {
        filename := scanner.Text()
        log.Println(filename)
    data, err := ioutil.ReadFile(filename)
    objregexp := regexp.MustCompile("obj-\\$\\((.+)\\)")
    if err != nil {
        panic(err)
    }
    for _, line := range strings.Split(string(data), "\n") {
        matches := objregexp.FindStringSubmatch(line)
        if len(matches) == 2 {
            i := strings.Index(line, "=")
            line = line[i:]
            vs := strings.Split(line, " ")
            for _, f := range vs[1:] {
                if len(f)-2 > 0 {
                    fmt.Println(f[:len(f)-2] + ".c", matches[1])
                }
            }
        }
    }
    }

}
