# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::taint;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Build ();

use Apache2::Const -compile => 'OK';

my $build = Apache2::Build->build_config;

sub handler {
    my $r = shift;

    my $tests = $build->{MP_COMPAT_1X} ? 4 : 2;

    plan $r, tests => $tests;

    ok t_cmp(${^TAINT}, 1, "\${^TAINT}");

    eval { ${^TAINT} = 0 };
    ok t_cmp($@, qr/read-only/, "\${^TAINT} is read-only");

    if ($build->{MP_COMPAT_1X}) {
        ok t_cmp($Apache2::__T, 1, "\$Apache2::__T");

        eval { $Apache2::__T = 0 };
        ok t_cmp($@, qr/read-only/, "\$Apache2::__T is read-only");
    }

    Apache2::Const::OK;
}

1;
__END__
