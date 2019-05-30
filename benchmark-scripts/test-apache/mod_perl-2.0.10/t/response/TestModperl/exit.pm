# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::exit;

# there is no need to call ModPerl::Util::exit() explicitly, a plain
# exit() will do. We do the explicit fully qualified call in this
# test, in case something has messed up with CORE::GLOBAL::exit and we
# want to make sure that we test the right API

use strict;
use warnings FATAL => 'all';

use ModPerl::Util ();

use Apache2::Const  -compile => 'OK';
use ModPerl::Const -compile => 'EXIT';

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    my $args = $r->args;

    if ($args eq 'eval') {
        eval {
            my $whatever = 1;
            ModPerl::Util::exit();
        };
        # test whether we can stringify our custom error messages
        $r->print("$@");
        ModPerl::Util::exit if $@ && ref $@ && $@ == ModPerl::EXIT;
    }
    elsif ($args eq 'noneval') {
        $r->print("exited");
        ModPerl::Util::exit();
    }

    # must not be reached
    $r->print("must not be reached");

    Apache2::Const::OK;
}

1;
__END__

