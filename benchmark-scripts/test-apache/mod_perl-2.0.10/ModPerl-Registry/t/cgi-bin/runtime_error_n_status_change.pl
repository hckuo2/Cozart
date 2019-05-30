# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
BEGIN {
    use Apache::TestUtil;
    t_server_log_error_is_expected();
}

use Apache2::Const -compile => qw(NOT_FOUND);

my $r = shift;
$r->status(Apache2::Const::NOT_FOUND);
$r->print("Content-type: text/plain\n\n");
$r->print(no_such_func());
