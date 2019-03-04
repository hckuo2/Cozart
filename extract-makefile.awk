function basename(file) {
    sub(".*/", "", file)
    return file
}
function dirname(file) {
    sub("/[^/]+$", "", file)
    return file
}

BEGIN{
}

{
    config = ""
    if (match($0, /^(obj|mounts|libdata)-\$\(CONFIG_(\w+)\)/, matches)) {
        config = "CONFIG_" matches[2]
    } else if(match($0, /^((?!obj\b)\w+)-y/, matches)) {
        config = "CONFIG_" toupper(matches[1])
    }
    dir = dirname(FILENAME)
    if (config) {
        for(i = 3; i <= NF; i++) {

            gsub("\.o$", "\.c", $i);
            print dir "/" $i, config

            # To handle this case: sd_mod.o <-> sd.c
            # Just duplicate an entry to not miss anything
            if (gsub("_mod", "", $i)) {
                print dir "/" $i, config
            }
        }
    }
}

END{
}
