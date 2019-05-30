# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;

plan tests => 8, need need_auth, 'mod_alias.c', 'HTML::HeadParser';

#so we don't have to require lwp
my @auth = (Authorization => 'Basic ZG91Z206Zm9v'); #dougm:foo


foreach my $location ("/perl_sections/index.html",
                      "/perl_sections_readconfig/index.html") {

    sok {
        ! GET_OK $location;
    };

    sok {
        my $rc = GET_RC $location;
        $rc == 401;
    };

    sok {
        GET_OK $location, @auth;
    };

    sok {
        ! GET_OK $location, $auth[0], $auth[1] . 'bogus';
    };
}
