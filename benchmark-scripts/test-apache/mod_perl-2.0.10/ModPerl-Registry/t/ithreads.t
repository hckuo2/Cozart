# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Config;

use constant HAS_ITHREADS => ($] >= 5.008001 && $Config{useithreads});

plan tests => 1, need 'mod_alias.c',
    {"perl 5.8.1 or higher w/ithreads enabled is required" => HAS_ITHREADS};

{
    # the order of prints on the server side is not important here,
    # what's important is that we get all the printed strings
    my @expected = sort map("thread $_", 1..4), "parent";
    my $url = "/registry_modperl_handler/ithreads_io_n_tie.pl";
    my $received = GET_BODY_ASSERT($url) || '';
    my @received = sort split /\n/, $received;
    ok t_cmp \@received, \@expected;
}
