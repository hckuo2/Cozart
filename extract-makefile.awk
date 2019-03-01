function basename(file) {
    sub(".*/", "", file)
    return file
}
function dirname(file) {
    sub("/[^/]+$", "", file)
    return file
}

BEGIN{
    # RS="[^\\\\]\n"
    print "Begin job"
}


{
    config = ""
    if (match($0, /^(obj|mounts|libdata)-\$\(CONFIG_(\w+)\)/, matches)) {
        config = "CONFIG_" matches[2]
    } else if(match($0, /^((?!obj\b)\w+)-y/, matches)) {
        config = "CONFIG_" toupper(matches[1])
    }
    dir = dirname(ARGV[1])
    if (config) {
        for(i = 3; i <= NF; i++) {
            gsub("_mod$", "", $i); # unix_mod.c <-> unix.o
            gsub("\.o$", "\.c", $i);
            print dir "/" $i, config
        }
    }
}

END{
    print "End job"
}
