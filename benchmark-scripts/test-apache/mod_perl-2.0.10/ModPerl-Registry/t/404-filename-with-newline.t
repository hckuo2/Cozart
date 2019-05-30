#!perl

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest qw(GET_RC);

plan tests => 1, need 'mod_alias.c';

{
    # this used to result in 500 due to a combination of Perl warning about
    # a newline in the filename passed to stat() and our
    #   use warnings FATAL=>'all'

    t_client_log_error_is_expected();
    my $url = '/registry/file%0dwith%0anl%0d%0aand%0a%0dcr';
    ok t_cmp GET_RC($url), 404, 'URL with \\r and \\n embedded';
}
