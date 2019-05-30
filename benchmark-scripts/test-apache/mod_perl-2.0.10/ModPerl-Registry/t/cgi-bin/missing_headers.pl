# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}
print "No HTTP headers were sent\n\n";

print "Here is some more body coming\n even with double new line\n\n";
print "Here is some more body coming";
