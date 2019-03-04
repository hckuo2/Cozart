BEGIN{
    startmark  = 0x333333333000
    endmark    = 0x222222222000
}
{
    if(match($0, /pc=0x([0-9a-fA-F]+) size=([0-9]+)/, matches)) {
        pc = matches[1]
        size = matches[2]
        if (local) {
            if (pc == startmark) {
                flag = "true"
            } else if (pc == endmark) {
                flag = ""
            }
            if (!flag) {
                next
            }
        }
        printf("%s,%x\n", pc, size)
    }
}
END{
}
