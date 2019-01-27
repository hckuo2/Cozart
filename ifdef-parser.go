package main

import (
    "log"
    "io/ioutil"
    "path/filepath"
    "os"
    "regexp"
    "strings"
    // "encoding/json"
    "fmt"
)

type location struct {
    path string
    start int
    end int
}

type item struct {
    name string
    locations []location
}

func parseFile(path string) map[string]*item {
    ifdef_regxp := regexp.MustCompile("#if(.+) (CONFIG_.+)")
    endif_regxp := regexp.MustCompile("#endif")
    data, err := ioutil.ReadFile(path)
    items := make(map[string]*item)

    if err != nil {
        log.Println(err)
    }
    var queue []string
    for idx, line := range strings.Split(string(data), "\n") {
        matches := ifdef_regxp.FindStringSubmatch(line)
        linenum := idx + 1
        if len(matches) == 3 {
            cname := matches[2]
            queue = append(queue, cname)
            l := location{path:path, start: linenum}
            if _, ok := items[cname]; !ok {
                items[cname] = &item{name: cname}
            }
            items[cname].locations = append(items[cname].locations, l)
        } else {
            matches := endif_regxp.FindStringSubmatch(line)
            if len(matches) == 1 {
                if len(queue) == 0 {
                    fmt.Printf("empty with #endif? path: %s line %d\n", path, linenum)
                    continue
                }
                cname := queue[len(queue)-1]
                queue = queue[:len(queue)-1]
                if items[cname].locations[len(items[cname].locations)-1].end != 0 {
                    panic("overwritting closed #endif " + cname)
                }
                items[cname].locations[len(items[cname].locations)-1].end = linenum
            }
        }
    }
    return items
}

func mergeResults(r1 map[string]*item, r2 map[string]*item)map[string]*item {
    for k, _ := range(r2) {
        if _, ok := r1[k]; ok {
            r1[k].locations = append(r1[k].locations, r2[k].locations...)
        } else {
            r1[k] = r2[k]
        }
    }
    return r1
}

func main() {
    var files []string
    source_regexp := regexp.MustCompile("^.+\\.[hc]$")
    root := os.Args[1]
    err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
        if err != nil {
            return err
        }
        if info.IsDir() {
            return nil
        }
        if source_regexp.MatchString(filepath.Base(path)) {
            files = append(files, path)
        }
        return nil
    })
    if err != nil {
        log.Println(err)
    }
    result := make(map[string]*item)
    for _, f := range(files) {
        r := parseFile(f)
        mergeResults(result, r)
    }
    fmt.Println(result)
}
