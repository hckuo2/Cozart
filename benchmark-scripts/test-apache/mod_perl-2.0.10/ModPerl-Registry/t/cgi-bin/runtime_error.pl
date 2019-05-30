# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

# this script sends no body at all, and since the error happens
# the script will return 500

print "Content-type: text/plain\n\n";
print no_such_func();
