# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::TestRequest 'GET_BODY_ASSERT';

use Apache::Test;
use Apache::TestUtil;

use ModPerl::Const -compile => 'EXIT';

my $location = "/TestModperl__exit";

plan tests => 3;

{
    ok t_cmp(GET_BODY_ASSERT("$location?noneval"),
             'exited',
             "exit in non eval context");

}
{
    my $exit_excpt = ModPerl::EXIT;
    my $body = GET_BODY_ASSERT("$location?eval");
    ok t_cmp($body,
             qr/^ModPerl::Util::exit: \($exit_excpt\) exit was called/,
             "exit in eval context");

    ok !t_cmp($body,
             qr/must not be reached/,
             "exit in eval context");

}
