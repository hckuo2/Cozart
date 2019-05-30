# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

use DoesNotExist ();

print "Content-type: text/plain\n\n";
print "this script is expected to fail";
