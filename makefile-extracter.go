package main
import (
    "fmt"
    "io/ioutil"
    "os"
    "strings"
    "regexp"
    "bufio"
)

func main() {
    scanner := bufio.NewScanner(os.Stdin)
    for scanner.Scan() {
        filename := scanner.Text()
        // log.Println(filename)
        data, err := ioutil.ReadFile(filename)
        objregexp := regexp.MustCompile("(obj|mounts|libdata)-\\$\\((.+)\\)")
        subobjregexp := regexp.MustCompile("(\\w+)-y")
        if err != nil {
            panic(err)
        }
        for _, line := range strings.Split(string(data), "\n") {
            matches := objregexp.FindStringSubmatch(line)
            if len(matches) == 3 {
                i := strings.Index(line, "=")
                if i == -1 {
                    continue
                }
                line = line[i:]
                vs := strings.Split(line, " ")
                for _, f := range vs[1:] {
                    if len(f)-2 > 0 {
                        basename := f[:len(f)-2]
                        fmt.Println(strings.Replace(basename, "_mod", "", 1) + ".c", matches[2])
                    }
                }
            } else {
                matches := subobjregexp.FindStringSubmatch(line)
                if len(matches) == 2 {
                    i := strings.Index(line, "=")
                    if i == -1 {
                        continue
                    }
                    line = line[i:]
                    vs := strings.Split(line, " ")
                    for _, f := range vs[1:] {
                        if len(f)-2 > 0 {
                            basename := f[:len(f)-2]
                            fmt.Println(strings.Replace(basename, "_mod", "", 1) + ".c", strings.ToUpper("CONFIG_" + matches[1]))
                        }
                    }
                }
            }
        }
    }

}
