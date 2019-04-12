function basename(file) {
    sub(".*/", "", file)
    return file
}
function dirname(file) {
    sub("/[^/]+$", "", file)
    return file
}
{
    config = ""
    if (match($0, /^(\w+)-\$\(CONFIG_(\w+)\)/, matches)) {
        config = "CONFIG_" matches[2]
    } else if(match($0, /^(\w+)-y/, matches)) {
        config = "CONFIG_" toupper(matches[1])
    } else if(match($0, /^(\w+)-objs/, matches)) {
        config = "CONFIG_" toupper(matches[1])
    }
    if ( config ~ /CONFIG_OBJ/ ) {
        next
    }

    dir = dirname(FILENAME)
    if (config) {
        for(i = 3; i <= NF; i++) {
            if ($i !~ /\.o/ && $i !~ /\w+\//) {
                continue
            }

            gsub("\.o$", "\.c", $i)
            print dir "/" $i, config

            # To handle this case: sd_mod.o <-> sd.c
            # Just duplicate an entry to not miss anything
            if (gsub("_mod", "", $i)) {
                print dir "/" $i, config
            }
        }
    }
}
