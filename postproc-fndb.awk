{
    if ( prev_config == $2 ) {
        if ( $1 == substr(prev_file, 0, length($1)) ) {
            next
        }
    }
    prev_file = $1
    prev_config = $2
    print $0
}
