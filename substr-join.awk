# if first file
function dirname(file) {
    sub("/[^/]+$", "", file)
    return file
}
FNR==NR {
    a[$1] = "true"
    next
}
{
    if (a[$1]) {
        print $2
    }
    dir=dirname($1)
    if (a[dir]) {
        print $2
    }
}
