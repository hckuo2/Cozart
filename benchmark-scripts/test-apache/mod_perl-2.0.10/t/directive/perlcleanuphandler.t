# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest 'GET_BODY';

plan tests => 3, need_lwp;

my $module = 'TestDirective::perlcleanuphandler';

Apache::TestRequest::user_agent(reset => 1, keep_alive=>1);
sub u {Apache::TestRequest::module2url($module, {path=>$_[0]})}

t_debug("connecting to ".u(''));
ok t_cmp GET_BODY(u('/get?incr')), 'UNDEF', 'before increment';
ok t_cmp GET_BODY(u('/get')), '1', 'incremented';
(undef)=GET_BODY(u('/index.html?incr'));
ok t_cmp GET_BODY(u('/get')), '2', 'incremented again';
