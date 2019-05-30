# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest qw(GET_BODY);
use Apache::Test;
use Apache::TestUtil;
use Apache::TestUtil qw/t_start_error_log_watch t_finish_error_log_watch/;

my $module = 'TestModperl::pnotes2';
my $url    = Apache::TestRequest::module2url($module);
my ($u, $ok);

t_debug("connecting to $url");

plan tests => 12, need_lwp;

Apache::TestRequest::user_agent(reset => 1, keep_alive => 0);

for my $i (1..12) {
    t_client_log_warn_is_expected();
    t_start_error_log_watch;
    $u="$url?$i"; $ok=GET_BODY $u;
    select undef, undef, undef, 0.2;  # give it time to write the logfile
    ok t_cmp scalar(grep {
        /pnotes are destroyed after cleanup passed/;
    } t_finish_error_log_watch), 1, $u;
}
