# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestVhost::config;

# Test whether under threaded mpms (and not) a vhost with 'PerlOptions
# +Parent', can run <Perl> sections, which call into config again via
# add_config().

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestUtil ();
use APR::Table ();

use File::Spec::Functions qw(canonpath catdir);

use Apache2::Const -compile => 'OK';

# initialized in t/htdocs/vhost/post_config.pl
our $restart_count;

# using a different from 'handler' name on purpose, to make sure
# that the module is preloaded at the server startup
sub my_handler {
    my $r = shift;

    plan $r, tests => 2;

    {
        my $expected = $r->document_root;
        my $received = $r->dir_config->get('DocumentRootCheck');
        ok t_cmp(canonpath($received), canonpath($expected), "DocumentRoot");
    }

    {
        ok t_cmp($restart_count, 2, "PerlPostConfigRequire");
    }

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestVhost::config>
    DocumentRoot @documentroot@/vhost

    <IfDefine PERL_USEITHREADS>
        # a new interpreter pool
        PerlOptions +Parent
        PerlInterpStart         1
        PerlInterpMax           1
        PerlInterpMinSpare      1
        PerlInterpMaxSpare      1
    </IfDefine>

    # use test system's @INC
    PerlSwitches -I@serverroot@

    # mp2 modules
    PerlRequire "@serverroot@/conf/modperl_inc.pl"

    # private to this vhost stuff
    PerlRequire "@documentroot@/vhost/startup.pl"
    PerlPostConfigRequire "@documentroot@/vhost/post_config.pl"

    # <Location /TestVhost__config> container is added via add_config
    # in t/htdocs/vhost/startup.pl
</VirtualHost>
</NoAutoConfig>
