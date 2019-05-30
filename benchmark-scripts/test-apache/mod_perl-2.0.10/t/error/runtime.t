# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

my $location = "/TestError__runtime";

my @untrapped = qw(plain_mp_error            plain_non_mp_error
                   die_hook_confess_mp_error die_hook_confess_non_mp_error
                   die_hook_custom_mp_error  die_hook_custom_non_mp_error);
my @trapped   = qw(eval_block_mp_error       eval_block_non_mp_error
                   eval_string_mp_error      eval_block_non_error
                   overload_test);

plan tests => @untrapped + @trapped;

for my $type (@untrapped) {
    my $res = GET("$location?$type");
    #t_debug($res->content);
    ok t_cmp(
        $res->code,
        500,
        "500 error on $type exception",
   );
}

for my $type (@trapped) {
    my $body = GET_BODY("$location?$type");
    ok t_cmp(
        $body,
        "ok $type",
        "200 on $type exception",
   );
}

