BEGIN{
    startmark  = 333333333000
    endmark    = 222222222000
}
{
    if(match($0, /pc=0x([0-9a-fA-F]+) size=([0-9]+)/, matches)) {
        pc = matches[1]
        size = matches[2]
        if (local) {
            if (pc ~ startmark) {
                flag = "true"
            } else if (pc ~ endmark) {
                flag = ""
            }
            if (!flag) {
                next
            }
        }

        # print if it's a kernel address
        if (pc ~ /ffff/) {
            printf("%s,%x\n", pc, size)
        }
    }
}
END{
}
